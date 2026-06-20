import 'dart:convert';
import 'dart:io';

import '../../../core/models/running_windows_app.dart';
import '../../../core/models/client_profile.dart';
import '../../../core/models/metrics_config.dart';
import '../../../core/models/runtime_paths.dart';
import '../../../core/models/runtime_status_snapshot.dart';
import '../../../core/models/split_tunnel_mode.dart';
import '../../../core/models/bad_app_scan_result.dart';
import '../../../core/models/app_update_info.dart';
import '../../../core/l10n/app_texts.dart';
import '../../../core/services/runtime_paths_service.dart';
import '../../../core/services/windows_app_selection_service.dart';
import '../../../core/services/app_autostart_service.dart';
import '../../../core/services/client_profile_codec.dart';
import '../../../core/services/client_profile_storage.dart';
import '../../../core/services/runtime_launcher.dart';
import '../../../core/services/bad_app_scan_result_storage.dart';
import '../../../core/services/bad_app_scanner_service.dart';
import '../../../core/services/app_update_service.dart';

class BootstrapState {
  const BootstrapState({
    required this.profile,
    required this.paths,
    required this.missingRuntimeFiles,
    required this.autoStartEnabled,
    this.badAppScanResult,
    this.savedProfileWarning,
    this.autoStartError,
  });

  final ClientProfile profile;
  final RuntimePaths paths;
  final List<String> missingRuntimeFiles;
  final bool autoStartEnabled;
  final BadAppScanResult? badAppScanResult;
  final String? savedProfileWarning;
  final String? autoStartError;
}

class ImportedProfile {
  const ImportedProfile({
    required this.filePath,
    required this.profile,
  });

  final String filePath;
  final ClientProfile profile;
}

class ClientController {
  ClientController({
    RuntimePathsService? runtimePathsService,
    WindowsAppSelectionService? windowsAppSelectionService,
    ClientProfileCodec? codec,
    ClientProfileStorage? storage,
    RuntimeLauncher? launcher,
    BadAppScannerService? badAppScannerService,
    BadAppScanResultStorage? badAppScanResultStorage,
    AppUpdateService? appUpdateService,
    AppLanguageSettings? appSettings,
    AppAutostartService? autostartService,
    AppTextCatalog? appTextCatalog,
  })  : _textCatalog =
            appTextCatalog ?? const AppTextCatalog(AppLanguage.english),
        _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService(),
        _windowsAppSelectionService = windowsAppSelectionService ??
            WindowsAppSelectionService(textCatalog: appTextCatalog),
        _codec = codec ?? ClientProfileCodec(appTextCatalog: appTextCatalog),
        _storage = storage ??
            ClientProfileStorage(
              codec: ClientProfileCodec(appTextCatalog: appTextCatalog),
              textCatalog: appTextCatalog,
            ),
        _launcher = launcher ?? RuntimeLauncher(appTextCatalog: appTextCatalog),
        _badAppScannerService = badAppScannerService ?? BadAppScannerService(),
        _badAppScanResultStorage =
            badAppScanResultStorage ?? BadAppScanResultStorage(),
        _appUpdateService = appUpdateService ?? AppUpdateService(),
        _appSettings = appSettings ?? AppLanguageSettings(),
        _autostartService = autostartService ?? const AppAutostartService();

  final RuntimePathsService _runtimePathsService;
  final WindowsAppSelectionService _windowsAppSelectionService;
  final ClientProfileCodec _codec;
  final ClientProfileStorage _storage;
  final RuntimeLauncher _launcher;
  final BadAppScannerService _badAppScannerService;
  final BadAppScanResultStorage _badAppScanResultStorage;
  final AppUpdateService _appUpdateService;
  final AppLanguageSettings _appSettings;
  final AppAutostartService _autostartService;
  final AppTextCatalog _textCatalog;

  Future<BootstrapState> bootstrap() async {
    final paths = await _runtimePathsService.getPaths();
    final missingRuntimeFiles =
        await _runtimePathsService.validateRuntime(paths);
    final savedProfile = await _loadSavedProfileForBootstrap();
    final badAppScanResult = await _badAppScanResultStorage.load();
    final autoStartEnabled = await _appSettings.loadAutoStartEnabled();
    String? autoStartError;
    try {
      await _autostartService.setEnabled(autoStartEnabled);
    } catch (error) {
      autoStartError = '$error';
    }

    return BootstrapState(
      profile: savedProfile.profile,
      paths: paths,
      missingRuntimeFiles: missingRuntimeFiles,
      autoStartEnabled: autoStartEnabled,
      badAppScanResult: badAppScanResult,
      savedProfileWarning: savedProfile.warning,
      autoStartError: autoStartError,
    );
  }

  String buildYamlPreview(ClientProfile profile) {
    return _codec.encodeYaml(profile);
  }

  ImportedProfile importProfileFromKey(String importKey) {
    final raw = _decodeImportKey(importKey);
    return ImportedProfile(
      filePath: 'mayday://import',
      profile: _codec.parseCurrentContractRaw(raw).copyWith(
            metrics: const MetricsConfig(),
          ),
    );
  }

  Future<File> saveProfile(ClientProfile profile) {
    return _storage.saveProfile(profile);
  }

  Future<LaunchResult> saveAndLaunch(
    ClientProfile profile,
  ) async {
    await _storage.saveProfile(profile);
    final runtimeConfig = await _storage.writeRuntimeConfig(profile);
    return _launcher.launch(
      configPath: runtimeConfig.path,
      deleteConfigAfterLaunch: true,
      requiresSplitTunnel: profile.splitTunnelMode != SplitTunnelMode.disabled,
    );
  }

  Future<StopResult> stopConnection() {
    return _launcher.stop();
  }

  Future<StopResult> shutdownRuntime() {
    return _launcher.shutdown();
  }

  bool get isRunning => _launcher.isRunning;

  Stream<bool> get runningChanges => _launcher.runningChanges;

  Stream<RuntimeStatusSnapshot> get runtimeStatusChanges =>
      _launcher.runtimeStatusChanges;

  Future<void> setAutoStartEnabled(bool enabled) async {
    await _autostartService.setEnabled(enabled);
    await _appSettings.saveAutoStartEnabled(enabled);
  }

  Future<String?> pickSplitTunnelExecutablePath() {
    return _windowsAppSelectionService.pickExecutablePath();
  }

  Future<List<RunningWindowsApp>> listRunningWindowsApps() {
    return _windowsAppSelectionService.listRunningApps();
  }

  Future<AppUpdateInfo?> checkForUpdate() {
    return _appUpdateService.checkForUpdate();
  }

  Future<void> openUpdatePage(AppUpdateInfo update) {
    return _appUpdateService.openReleasePage(update.releaseUrl);
  }

  Future<BadAppScanResult> scanBadAppFindings() async {
    final findings = await _badAppScannerService.scan();
    final result = BadAppScanResult(
      scannedAt: DateTime.now(),
      findings: findings,
    );
    try {
      await _badAppScanResultStorage.save(result);
    } catch (_) {
      // The scan result is still valid for this session if the cache fails.
    }
    return result;
  }

  Future<_SavedProfileBootstrapResult> _loadSavedProfileForBootstrap() async {
    try {
      final profile = await _storage.loadSavedProfileForCurrentContract();
      return _SavedProfileBootstrapResult(
        profile: profile ?? const ClientProfile(),
      );
    } on ClientProfileContractException {
      return _SavedProfileBootstrapResult(
        profile: const ClientProfile(),
        warning: _textCatalog.t('message.saved_config_incompatible'),
      );
    } catch (_) {
      return _SavedProfileBootstrapResult(
        profile: const ClientProfile(),
        warning: _textCatalog.t('message.saved_config_incompatible'),
      );
    }
  }

  String _decodeImportKey(String importKey) {
    final value = importKey.trim();
    if (value.isEmpty) {
      throw FormatException(_textCatalog.t('error.import_key_empty'));
    }

    final payload = _extractImportPayload(value);
    final decodedPayload = Uri.decodeComponent(payload)
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    final paddingLength = (4 - decodedPayload.length % 4) % 4;
    final paddedPayload = '$decodedPayload${'=' * paddingLength}';
    return utf8.decode(base64.decode(paddedPayload));
  }

  String _extractImportPayload(String value) {
    const prefix = 'mayday://import/';
    if (value.toLowerCase().startsWith(prefix)) {
      return value.substring(prefix.length);
    }

    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme.toLowerCase() == 'mayday' &&
        uri.host.toLowerCase() == 'import') {
      final data = uri.queryParameters['data'];
      if (data != null && data.isNotEmpty) {
        return data;
      }
      final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      if (path.isNotEmpty) {
        return path;
      }
    }

    return value;
  }
}

class _SavedProfileBootstrapResult {
  const _SavedProfileBootstrapResult({
    required this.profile,
    this.warning,
  });

  final ClientProfile profile;
  final String? warning;
}

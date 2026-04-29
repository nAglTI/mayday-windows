import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/models/running_windows_app.dart';
import '../../../core/models/client_profile.dart';
import '../../../core/models/runtime_paths.dart';
import '../../../core/models/split_tunnel_mode.dart';
import '../../../core/l10n/app_texts.dart';
import '../../../core/services/config_file_picker_service.dart';
import '../../../core/services/runtime_paths_service.dart';
import '../../../core/services/windows_app_selection_service.dart';
import '../../../core/services/app_autostart_service.dart';
import '../../../core/services/client_profile_codec.dart';
import '../../../core/services/client_profile_storage.dart';
import '../../../core/services/runtime_launcher.dart';

class BootstrapState {
  const BootstrapState({
    required this.profile,
    required this.paths,
    required this.missingRuntimeFiles,
    required this.autoStartEnabled,
    this.autoStartError,
  });

  final ClientProfile profile;
  final RuntimePaths paths;
  final List<String> missingRuntimeFiles;
  final bool autoStartEnabled;
  final String? autoStartError;
}

class ImportedProfile {
  const ImportedProfile({
    required this.fileName,
    required this.filePath,
    required this.profile,
  });

  final String fileName;
  final String filePath;
  final ClientProfile profile;
}

class ClientController {
  ClientController({
    ConfigFilePickerService? configFilePickerService,
    RuntimePathsService? runtimePathsService,
    WindowsAppSelectionService? windowsAppSelectionService,
    ClientProfileCodec? codec,
    ClientProfileStorage? storage,
    RuntimeLauncher? launcher,
    AppLanguageSettings? appSettings,
    AppAutostartService? autostartService,
    AppTextCatalog? appTextCatalog,
  })  : _textCatalog =
            appTextCatalog ?? const AppTextCatalog(AppLanguage.english),
        _configFilePickerService = configFilePickerService ??
            ConfigFilePickerService(textCatalog: appTextCatalog),
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
        _appSettings = appSettings ?? AppLanguageSettings(),
        _autostartService = autostartService ?? const AppAutostartService();

  final ConfigFilePickerService _configFilePickerService;
  final RuntimePathsService _runtimePathsService;
  final WindowsAppSelectionService _windowsAppSelectionService;
  final ClientProfileCodec _codec;
  final ClientProfileStorage _storage;
  final RuntimeLauncher _launcher;
  final AppLanguageSettings _appSettings;
  final AppAutostartService _autostartService;
  final AppTextCatalog _textCatalog;

  Future<BootstrapState> bootstrap() async {
    final paths = await _runtimePathsService.getPaths();
    final missingRuntimeFiles =
        await _runtimePathsService.validateRuntime(paths);
    final savedProfile = await _storage.loadSavedProfile();
    final autoStartEnabled = await _appSettings.loadAutoStartEnabled();
    String? autoStartError;
    try {
      await _autostartService.setEnabled(autoStartEnabled);
    } catch (error) {
      autoStartError = '$error';
    }

    return BootstrapState(
      profile: savedProfile ?? const ClientProfile(),
      paths: paths,
      missingRuntimeFiles: missingRuntimeFiles,
      autoStartEnabled: autoStartEnabled,
      autoStartError: autoStartError,
    );
  }

  String buildYamlPreview(ClientProfile profile) {
    return _codec.encodeYaml(profile);
  }

  Future<ImportedProfile?> pickAndImportProfile() async {
    final filePath = await _configFilePickerService.pickConfigPath();
    if (filePath == null) {
      return null;
    }

    final raw = await File(filePath).readAsString();
    final fileName = p.basename(filePath);
    final displayName = p.basenameWithoutExtension(filePath).trim();
    return ImportedProfile(
      fileName: fileName,
      filePath: filePath,
      profile: _codec.parseRaw(
        raw,
        currentProfileName: displayName.isNotEmpty
            ? displayName
            : _textCatalog.t('codec.imported_default_name'),
      ),
    );
  }

  ImportedProfile importProfileFromKey(String importKey) {
    final raw = _decodeImportKey(importKey);
    return ImportedProfile(
      fileName: _textCatalog.t('file.import_key_name'),
      filePath: 'mayday://import',
      profile: _codec.parseRaw(
        raw,
        currentProfileName: _textCatalog.t('codec.imported_default_name'),
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

  bool get isRunning => _launcher.isRunning;

  Stream<bool> get runningChanges => _launcher.runningChanges;

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

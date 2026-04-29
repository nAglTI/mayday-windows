import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:path/path.dart' as p;

import '../../../core/l10n/app_texts.dart';
import '../../../core/models/running_windows_app.dart';
import '../../../core/models/split_tunnel_mode.dart';
import '../../../core/models/client_profile.dart';
import '../../../core/models/metrics_config.dart';
import '../../../core/models/relay_target.dart';
import '../../../core/models/runtime_paths.dart';
import '../../../core/models/server_target.dart';
import '../../../core/services/runtime_launcher.dart';
import '../../../core/services/tray_icon_service.dart';
import '../../../core/models/transport_config.dart';
import '../application/client_controller.dart';

enum HomeSection { connection, settings }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required ClientController controller,
    required AppTextCatalog textCatalog,
    TrayIconService trayIconService = const TrayIconService(),
  })  : _controller = controller,
        _textCatalog = textCatalog,
        _trayIconService = trayIconService {
    _watchController();
  }

  ClientController _controller;
  AppTextCatalog _textCatalog;
  final TrayIconService _trayIconService;
  StreamSubscription<bool>? _runningSubscription;

  final displayNameController = TextEditingController();
  final userIdController = TextEditingController();
  final tunNameController = TextEditingController();
  final dnsController = TextEditingController();
  final failbackDelayController = TextEditingController();
  final metricsWindowController = TextEditingController();
  final metricsFileDirController = TextEditingController();

  SplitTunnelMode splitTunnelMode = SplitTunnelMode.disabled;
  TransportMode transportMode = TransportMode.auto;
  bool metricsEnabled = true;
  bool metricsFileEnabled = true;
  bool autoStartEnabled = true;
  List<RelayTarget> relays = const [];
  List<ServerTarget> servers = const [];
  List<String> windowsApps = const [];
  List<String> profileAndroidApps = const [];
  Map<String, Object?> profileExtraFields = const {};
  Map<String, Object?> transportExtraFields = const {};
  Map<String, Object?> metricsExtraFields = const {};
  Map<String, Object?> splitTunnelExtraFields = const {};
  bool isBusy = true;
  bool isRuntimeStarted = false;
  String busyStatusText = 'status.working';
  HomeSection selectedSection = HomeSection.connection;

  String? statusMessage;
  String? errorMessage;
  String? lastImportedPath;
  RuntimePaths? paths;
  List<String> missingRuntimeFiles = const [];

  String t(String key, [Map<String, Object?>? values]) {
    return _textCatalog.t(key, values);
  }

  void updateDependencies({
    required ClientController controller,
    required AppTextCatalog textCatalog,
  }) {
    if (_controller != controller) {
      _controller = controller;
      _watchController();
    }
    _textCatalog = textCatalog;
    _setRuntimeStarted(_controller.isRunning);
    notifyListeners();
  }

  @override
  void dispose() {
    _runningSubscription?.cancel();
    displayNameController.dispose();
    userIdController.dispose();
    tunNameController.dispose();
    dnsController.dispose();
    failbackDelayController.dispose();
    metricsWindowController.dispose();
    metricsFileDirController.dispose();
    super.dispose();
  }

  Future<void> bootstrap() async {
    _setBusy(true, statusKey: 'status.loading', clearError: true);

    try {
      final state = await _controller.bootstrap();
      _applyProfile(state.profile);
      paths = state.paths;
      missingRuntimeFiles = state.missingRuntimeFiles;
      autoStartEnabled = state.autoStartEnabled;
      _setRuntimeStarted(_controller.isRunning);
      final runtimeStatus = state.missingRuntimeFiles.isEmpty
          ? t('message.runtime_available')
          : t('message.runtime_incomplete');
      statusMessage = state.autoStartError == null
          ? runtimeStatus
          : '$runtimeStatus ${t('message.autostart_apply_failed', {
                  'error': state.autoStartError,
                })}';
    } catch (error) {
      errorMessage = t('message.bootstrap_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> importConfig() async {
    _setBusy(true, statusKey: 'status.importing', clearError: true);

    try {
      final result = await _controller.pickAndImportProfile();
      if (result == null) {
        statusMessage = t('message.import_cancelled');
        return;
      }

      _applyProfile(result.profile);
      lastImportedPath = result.filePath;
      statusMessage = t('message.imported_file', {'file': result.fileName});
    } catch (error) {
      errorMessage = t('message.import_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> importConfigFromKey(String importKey) async {
    _setBusy(true, statusKey: 'status.importing', clearError: true);

    try {
      final result = _controller.importProfileFromKey(importKey);
      _applyProfile(result.profile);
      lastImportedPath = result.filePath;
      statusMessage = t('message.imported_from_key');
    } catch (error) {
      errorMessage = t('message.import_key_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveProfile() async {
    _setBusy(true, statusKey: 'status.saving', clearError: true);

    try {
      final file = await _controller.saveProfile(collectProfile());
      statusMessage = t('message.config_saved', {'path': file.path});
    } catch (error) {
      errorMessage = t('message.save_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveAndLaunch() async {
    _setBusy(true, statusKey: 'status.connecting', clearError: true);

    try {
      final result = await _controller.saveAndLaunch(collectProfile());
      _applyLaunchResult(result);
    } catch (error) {
      errorMessage = t('message.launch_failed', {'error': error});
      _setRuntimeStarted(false);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> stopConnection() async {
    _setBusy(true, statusKey: 'status.stopping', clearError: true);

    try {
      final result = await _controller.stopConnection();
      _applyStopResult(result);
    } catch (error) {
      errorMessage = t('message.stop_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> addSplitTunnelAppFromFile() async {
    try {
      final path = await _controller.pickSplitTunnelExecutablePath();
      if (path == null || path.trim().isEmpty) {
        return;
      }
      addSplitTunnelApp(path);
    } catch (error) {
      errorMessage = t('message.app_picker_failed', {'error': error});
      notifyListeners();
    }
  }

  Future<List<RunningWindowsApp>> listRunningWindowsApps() async {
    _setBusy(true, statusKey: 'status.loading_apps', clearError: true);

    try {
      return await _controller.listRunningWindowsApps();
    } catch (error) {
      errorMessage = t('message.running_list_failed', {'error': error});
      return const [];
    } finally {
      _setBusy(false);
    }
  }

  void setSelectedSection(HomeSection section) {
    if (selectedSection == section) {
      return;
    }
    selectedSection = section;
    notifyListeners();
  }

  void setSplitTunnelMode(SplitTunnelMode mode) {
    splitTunnelMode = mode;
    notifyListeners();
  }

  void setTransportMode(TransportMode mode) {
    transportMode = mode;
    notifyListeners();
  }

  void setMetricsEnabled(bool value) {
    metricsEnabled = value;
    notifyListeners();
  }

  void setMetricsFileEnabled(bool value) {
    metricsFileEnabled = value;
    notifyListeners();
  }

  Future<void> setAutoStartEnabled(bool value) async {
    _setBusy(true, statusKey: 'status.saving', clearError: true);

    try {
      await _controller.setAutoStartEnabled(value);
      autoStartEnabled = value;
      statusMessage = value
          ? t('message.autostart_enabled')
          : t('message.autostart_disabled');
    } catch (error) {
      errorMessage = t('message.autostart_save_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  void addSplitTunnelApp(String appPath) {
    windowsApps = _normalizeWindowsApps([...windowsApps, appPath]);
    statusMessage = t('message.added_split_app', {
      'app': _displayAppPath(appPath),
    });
    errorMessage = null;
    notifyListeners();
  }

  void removeSplitTunnelApp(String appPath) {
    windowsApps = [
      for (final app in windowsApps)
        if (app != appPath) app,
    ];
    notifyListeners();
  }

  void reorderServers(int oldIndex, int newIndex) {
    if (isBusy) {
      return;
    }

    final updated = [...servers];
    final item = updated.removeAt(oldIndex);
    final insertionIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updated.insert(insertionIndex, item);
    servers = [
      for (var index = 0; index < updated.length; index += 1)
        updated[index].copyWith(priority: index + 1),
    ];
    notifyListeners();
  }

  ClientProfile collectProfile() {
    final displayName = displayNameController.text.trim();
    final dnsServers = _parseCsv(dnsController.text);

    return ClientProfile(
      displayName: displayName.isEmpty ? t('home.primary') : displayName,
      relays: relays,
      userId: userIdController.text.trim(),
      servers: _normalizeServerPriorities(servers),
      tunName: tunNameController.text.trim(),
      dnsServers: dnsServers.isEmpty ? const ['1.1.1.1'] : dnsServers,
      transport: TransportConfig(
        mode: transportMode,
        extraFields: transportExtraFields,
      ),
      metrics: MetricsConfig(
        enabled: metricsEnabled,
        windowSeconds: int.tryParse(metricsWindowController.text.trim()) ?? 600,
        fileEnabled: metricsFileEnabled,
        fileDir: metricsFileDirController.text.trim(),
        extraFields: metricsExtraFields,
      ),
      serverFailbackDelaySec:
          int.tryParse(failbackDelayController.text.trim()) ?? 60,
      splitTunnelMode: splitTunnelMode,
      windowsApps: _normalizeWindowsApps(windowsApps),
      androidApps: profileAndroidApps,
      splitTunnelExtraFields: splitTunnelExtraFields,
      extraFields: profileExtraFields,
    );
  }

  bool configurationReady(ClientProfile profile) {
    return profile.relays.isNotEmpty &&
        profile.userId.trim().isNotEmpty &&
        profile.servers.isNotEmpty;
  }

  String connectionSummary(ClientProfile profile, bool engineReady) {
    if (!engineReady) {
      return t('home.runtime_not_ready');
    }
    if (!configurationReady(profile)) {
      return t('home.config_not_ready');
    }
    return t('home.config_ready');
  }

  String splitModeLabel(SplitTunnelMode mode) {
    return switch (mode) {
      SplitTunnelMode.disabled => t('label.all_traffic'),
      SplitTunnelMode.onlySelected => t('label.only_selected'),
      SplitTunnelMode.excludeSelected => t('label.except'),
    };
  }

  String get connectionStatus {
    if (isBusy) {
      return t(busyStatusText);
    }
    if (errorMessage != null) {
      return t('status.disconnected');
    }
    if (isRuntimeStarted) {
      return t('status.connected');
    }
    return t('status.disconnected');
  }

  String get statusLine {
    if (errorMessage != null) {
      return t('status.launch_error');
    }
    if (isBusy) {
      return t(busyStatusText);
    }
    if (isRuntimeStarted) {
      return t('status.runtime_started');
    }
    return t('status.idle');
  }

  bool get engineReady => missingRuntimeFiles.isEmpty;

  String metricsDirectory(ClientProfile profile) {
    final fileDir = profile.metrics.fileDir.trim();
    if (fileDir.isEmpty) {
      return paths?.runtimeDir ?? '';
    }
    if (p.isAbsolute(fileDir) || paths == null) {
      return fileDir;
    }
    return p.normalize(p.join(paths!.runtimeDir, fileDir));
  }

  void _setBusy(
    bool value, {
    String? statusKey,
    bool clearError = false,
  }) {
    isBusy = value;
    if (statusKey != null) {
      busyStatusText = statusKey;
    }
    if (clearError) {
      errorMessage = null;
    }
    notifyListeners();
  }

  void _applyProfile(ClientProfile profile) {
    displayNameController.text = profile.displayName;
    userIdController.text = profile.userId;
    tunNameController.text = profile.tunName;
    dnsController.text = profile.dnsServers.join(', ');
    failbackDelayController.text = '${profile.serverFailbackDelaySec}';
    metricsWindowController.text = '${profile.metrics.windowSeconds}';
    metricsFileDirController.text = profile.metrics.fileDir;
    transportMode = profile.transport.mode;
    metricsEnabled = profile.metrics.enabled;
    metricsFileEnabled = profile.metrics.fileEnabled;
    relays = profile.relays;
    servers = _normalizeServerPriorities(profile.servers);
    windowsApps = _normalizeWindowsApps(profile.windowsApps);
    profileAndroidApps = _normalizeWindowsApps(profile.androidApps);
    profileExtraFields = profile.extraFields;
    transportExtraFields = profile.transport.extraFields;
    metricsExtraFields = profile.metrics.extraFields;
    splitTunnelExtraFields = profile.splitTunnelExtraFields;
    splitTunnelMode = profile.splitTunnelMode;
  }

  void _applyLaunchResult(LaunchResult result) {
    if (result.success) {
      _setRuntimeStarted(true);
      final pidSuffix = result.processId == null
          ? ''
          : t('message.pid_suffix', {'pid': result.processId});
      statusMessage = '${result.message}$pidSuffix';
      errorMessage = null;
    } else {
      _setRuntimeStarted(false);
      errorMessage = result.message;
    }
  }

  void _applyStopResult(StopResult result) {
    if (result.success) {
      _setRuntimeStarted(false);
      statusMessage = result.message;
      errorMessage = null;
    } else {
      errorMessage = result.message;
    }
  }

  void _watchController() {
    _runningSubscription?.cancel();
    _runningSubscription = _controller.runningChanges.listen((isRunning) {
      if (isRuntimeStarted == isRunning) {
        _syncTrayIcon();
        return;
      }

      _setRuntimeStarted(isRunning);
      notifyListeners();
    });
  }

  void _setRuntimeStarted(bool value) {
    isRuntimeStarted = value;
    _syncTrayIcon();
  }

  void _syncTrayIcon() {
    unawaited(_trayIconService.setVpnConnected(isRuntimeStarted));
  }

  List<ServerTarget> _normalizeServerPriorities(
    List<ServerTarget> servers,
  ) {
    final sorted = [...servers]..sort((left, right) {
        final priorityCompare = left.priority.compareTo(right.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return left.id.compareTo(right.id);
      });

    return [
      for (var index = 0; index < sorted.length; index += 1)
        sorted[index].copyWith(priority: index + 1),
    ];
  }

  List<String> _parseCsv(String text) {
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _normalizeWindowsApps(Iterable<String> values) {
    final seen = <String>{};
    final apps = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) {
        continue;
      }
      apps.add(trimmed);
    }
    return apps;
  }

  String _displayAppPath(String appPath) {
    final normalized = appPath.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}

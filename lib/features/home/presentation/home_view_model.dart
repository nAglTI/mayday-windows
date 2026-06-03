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
import '../../../core/models/network_rescue_config.dart';
import '../../../core/models/bad_app_finding.dart';
import '../../../core/models/bad_app_scan_result.dart';
import '../../../core/models/app_update_info.dart';
import '../../../core/services/client_profile_codec.dart';
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
  Future<BadAppScanResult>? _activeBadAppScan;
  Future<AppUpdateInfo?>? _activeUpdateCheck;
  bool _sessionBadAppScanStarted = false;
  bool _disposed = false;

  final userIdController = TextEditingController();
  final tunNameController = TextEditingController();
  final dnsController = TextEditingController();
  final failbackDelayController = TextEditingController();
  final metricsWindowController = TextEditingController();
  final metricsFileDirController = TextEditingController();
  final tunnelMtuController = TextEditingController();
  final packetFragmentPayloadController = TextEditingController();

  SplitTunnelMode splitTunnelMode = SplitTunnelMode.disabled;
  TransportMode transportMode = TransportMode.auto;
  NetworkRescueProfile networkRescueProfile = NetworkRescueProfile.off;
  bool metricsEnabled = true;
  bool metricsFileEnabled = true;
  bool autoStartEnabled = true;
  bool prestartFullProbe = false;
  bool steadyStateQuickProbeEnabled = false;
  bool steadyStateBenchmarkEnabled = false;
  bool disableIpv6 = false;
  int tunnelMtu = 1280;
  int packetFragmentPayloadBytes = 0;
  bool disablePacketBatching = false;
  List<RelayTarget> relays = const [];
  List<ServerTarget> servers = const [];
  List<String> windowsApps = const [];
  List<String> profileAndroidApps = const [];
  Map<String, Object?> profileExtraFields = const {};
  Map<String, Object?> transportExtraFields = const {};
  Map<String, Object?> networkRescueExtraFields = const {};
  Map<String, Object?> metricsExtraFields = const {};
  Map<String, Object?> splitTunnelExtraFields = const {};
  bool isBusy = true;
  bool isRuntimeStarted = false;
  String busyStatusText = 'status.working';
  HomeSection selectedSection = HomeSection.connection;

  String? statusMessage;
  String? errorMessage;
  String? warningMessage;
  String? lastImportedPath;
  RuntimePaths? paths;
  List<String> missingRuntimeFiles = const [];
  List<BadAppFinding>? badAppFindings;
  DateTime? badAppScannedAt;
  bool badAppScanFailed = false;
  bool badAppScanRanThisSession = false;
  AppUpdateInfo? availableUpdate;
  String? _dismissedUpdateVersion;

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
    _disposed = true;
    _runningSubscription?.cancel();
    unawaited(_controller.shutdownRuntime());
    userIdController.dispose();
    tunNameController.dispose();
    dnsController.dispose();
    failbackDelayController.dispose();
    metricsWindowController.dispose();
    metricsFileDirController.dispose();
    tunnelMtuController.dispose();
    packetFragmentPayloadController.dispose();
    super.dispose();
  }

  Future<void> bootstrap() async {
    _setBusy(
      true,
      statusKey: 'status.loading',
      clearError: true,
      clearWarning: true,
    );
    var shouldStartSessionScan = false;

    try {
      final state = await _controller.bootstrap();
      _applyProfile(state.profile);
      paths = state.paths;
      missingRuntimeFiles = state.missingRuntimeFiles;
      autoStartEnabled = state.autoStartEnabled;
      badAppFindings = state.badAppScanResult?.findings;
      badAppScannedAt = state.badAppScanResult?.scannedAt;
      badAppScanFailed = false;
      badAppScanRanThisSession = false;
      _setRuntimeStarted(_controller.isRunning);
      final runtimeStatus = state.missingRuntimeFiles.isEmpty
          ? t('message.runtime_available')
          : t('message.runtime_incomplete');
      statusMessage = state.autoStartError == null
          ? runtimeStatus
          : '$runtimeStatus ${t('message.autostart_apply_failed', {
                  'error': state.autoStartError,
                })}';
      warningMessage = state.savedProfileWarning;
      shouldStartSessionScan = true;
    } catch (error) {
      errorMessage = t('message.bootstrap_failed', {'error': error});
    } finally {
      _setBusy(false);
      if (shouldStartSessionScan && !_disposed) {
        _startSessionBadAppScan();
        _startUpdateCheck();
      }
    }
  }

  Future<void> importConfigFromKey(String importKey) async {
    _setBusy(
      true,
      statusKey: 'status.importing',
      clearError: true,
      clearWarning: true,
    );

    try {
      final result = _controller.importProfileFromKey(importKey);
      _applyProfile(result.profile);
      lastImportedPath = result.filePath;
      warningMessage = null;
      statusMessage = t('message.imported_from_key');
    } on ClientProfileContractException {
      errorMessage = t('message.import_key_incompatible');
    } catch (error) {
      errorMessage = t('message.import_key_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveProfile() async {
    _setBusy(
      true,
      statusKey: 'status.saving',
      clearError: true,
      clearWarning: true,
    );

    try {
      final file = await _controller.saveProfile(collectProfile());
      warningMessage = null;
      statusMessage = t('message.config_saved', {'path': file.path});
    } catch (error) {
      errorMessage = t('message.save_failed', {'error': error});
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveAndLaunch() async {
    _setBusy(
      true,
      statusKey: 'status.connecting',
      clearError: true,
      clearWarning: true,
    );

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

  Future<List<BadAppFinding>?> scanBadAppFindings() async {
    _setBusy(
      true,
      statusKey: 'status.scanning_apps',
      clearError: true,
      clearWarning: true,
    );

    try {
      final result = await _runBadAppScan();
      final findings = result.findings;
      _applyBadAppScanResult(result);
      if (findings.isNotEmpty) {
        statusMessage = null;
        errorMessage = null;
        warningMessage = t('message.vpn_scan_blocked', {
          'count': findings.length,
        });
      } else {
        errorMessage = null;
        warningMessage = null;
        statusMessage = t('message.vpn_scan_clear');
      }
      return findings;
    } catch (error) {
      statusMessage = null;
      warningMessage = null;
      badAppScanRanThisSession = true;
      badAppScanFailed = true;
      errorMessage = t('message.vpn_scan_failed', {'error': error});
      return null;
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

  void setNetworkRescueProfile(NetworkRescueProfile profile) {
    networkRescueProfile = profile;
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

  void setPrestartFullProbe(bool value) {
    prestartFullProbe = value;
    notifyListeners();
  }

  void setSteadyStateQuickProbeEnabled(bool value) {
    steadyStateQuickProbeEnabled = value;
    notifyListeners();
  }

  void setSteadyStateBenchmarkEnabled(bool value) {
    steadyStateBenchmarkEnabled = value;
    notifyListeners();
  }

  void setDisableIpv6(bool value) {
    disableIpv6 = value;
    notifyListeners();
  }

  void setTunnelMtuFromText(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    tunnelMtu = parsed;
    notifyListeners();
  }

  void setPacketFragmentPayloadFromText(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    packetFragmentPayloadBytes = parsed;
    notifyListeners();
  }

  void setPacketFragmentPayloadBytes(int value) {
    packetFragmentPayloadBytes = value;
    packetFragmentPayloadController.text = '$value';
    notifyListeners();
  }

  void setDisablePacketBatching(bool value) {
    disablePacketBatching = value;
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
    addSplitTunnelApps([appPath]);
  }

  void addSplitTunnelApps(Iterable<String> appPaths) {
    final previousApps = windowsApps;
    final previousAppKeys = {
      for (final app in previousApps) app.toLowerCase(),
    };
    windowsApps = _normalizeWindowsApps([...windowsApps, ...appPaths]);
    final addedApps = [
      for (final app in windowsApps)
        if (!previousAppKeys.contains(app.toLowerCase())) app,
    ];
    if (addedApps.isEmpty) {
      notifyListeners();
      return;
    }

    statusMessage = addedApps.length == 1
        ? t('message.added_split_app', {
            'app': _displayAppPath(addedApps.single),
          })
        : t('message.added_split_apps', {
            'count': addedApps.length,
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
    final dnsServers = _parseCsv(dnsController.text);

    return ClientProfile(
      relays: relays,
      userId: userIdController.text.trim(),
      servers: _normalizeServerPriorities(servers),
      tunName: tunNameController.text.trim(),
      dnsServers: dnsServers.isEmpty ? const ['1.1.1.1'] : dnsServers,
      transport: TransportConfig(
        mode: transportMode,
        extraFields: transportExtraFields,
      ),
      networkRescue: NetworkRescueConfig(
        profile: networkRescueProfile,
        extraFields: networkRescueExtraFields,
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
      prestartFullProbe: prestartFullProbe,
      steadyStateQuickProbeEnabled: steadyStateQuickProbeEnabled,
      steadyStateBenchmarkEnabled: steadyStateBenchmarkEnabled,
      disableIpv6: disableIpv6,
      tunnelMtu: int.tryParse(tunnelMtuController.text.trim()) ?? tunnelMtu,
      packetFragmentPayloadBytes:
          int.tryParse(packetFragmentPayloadController.text.trim()) ??
              packetFragmentPayloadBytes,
      disablePacketBatching: disablePacketBatching,
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

  String transportModeLabel(TransportMode mode) {
    return switch (mode) {
      TransportMode.auto => t('label.transport_auto'),
      TransportMode.tcp => t('label.transport_tcp'),
      TransportMode.utp => t('label.transport_utp'),
      TransportMode.ws => t('label.transport_ws'),
      TransportMode.https => t('label.transport_https'),
      TransportMode.rawUdp => t('label.transport_raw_udp'),
    };
  }

  String networkRescueProfileLabel(NetworkRescueProfile profile) {
    return switch (profile) {
      NetworkRescueProfile.off => t('label.network_rescue_off'),
      NetworkRescueProfile.stable => t('label.network_rescue_stable'),
      NetworkRescueProfile.extreme => t('label.network_rescue_extreme'),
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

  bool get hasBadAppScanResult => badAppFindings != null;

  bool get isBadAppPreflightPassed =>
      badAppScanRanThisSession &&
      !badAppScanFailed &&
      badAppFindings != null &&
      badAppFindings!.isEmpty;

  bool get shouldShowUpdateBanner {
    final update = availableUpdate;
    return update != null &&
        update.latestVersion.displayVersion != _dismissedUpdateVersion;
  }

  String get badAppScanSummary {
    if (!badAppScanRanThisSession) {
      return t('status.not_scanned');
    }
    if (badAppScanFailed) {
      return t('status.scan_failed');
    }
    final findings = badAppFindings;
    if (findings == null) {
      return t('status.not_scanned');
    }
    if (findings.isEmpty) {
      return t('status.scan_clear');
    }
    return t('status.scan_blocked_count', {'count': findings.length});
  }

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

  void dismissAvailableUpdate() {
    final update = availableUpdate;
    if (update == null) {
      return;
    }

    _dismissedUpdateVersion = update.latestVersion.displayVersion;
    notifyListeners();
  }

  Future<void> openAvailableUpdate() async {
    final update = availableUpdate;
    if (update == null) {
      return;
    }

    try {
      await _controller.openUpdatePage(update);
    } catch (error) {
      errorMessage = t('message.update_open_failed', {'error': error});
      notifyListeners();
    }
  }

  void _startSessionBadAppScan() {
    if (_sessionBadAppScanStarted) {
      return;
    }

    _sessionBadAppScanStarted = true;
    unawaited(_refreshBadAppScanInBackground());
  }

  void _startUpdateCheck() {
    unawaited(_refreshUpdateInBackground());
  }

  Future<void> _refreshBadAppScanInBackground() async {
    try {
      final result = await _runBadAppScan();
      if (_disposed) {
        return;
      }

      _applyBadAppScanResult(result);
      notifyListeners();
    } catch (_) {
      if (_disposed) {
        return;
      }

      badAppScanRanThisSession = true;
      badAppScanFailed = true;
      notifyListeners();
    }
  }

  Future<BadAppScanResult> _runBadAppScan() {
    final activeScan = _activeBadAppScan;
    if (activeScan != null) {
      return activeScan;
    }

    final scan = _controller.scanBadAppFindings();
    _activeBadAppScan = scan;
    unawaited(
      scan.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (identical(_activeBadAppScan, scan)) {
          _activeBadAppScan = null;
        }
      }),
    );
    return scan;
  }

  Future<void> _refreshUpdateInBackground() async {
    try {
      final update = await _runUpdateCheck();
      if (_disposed) {
        return;
      }

      availableUpdate = update;
      notifyListeners();
    } catch (_) {
      // Update checks are advisory; network failures should not disturb use.
    }
  }

  Future<AppUpdateInfo?> _runUpdateCheck() {
    final activeCheck = _activeUpdateCheck;
    if (activeCheck != null) {
      return activeCheck;
    }

    final check = _controller.checkForUpdate();
    _activeUpdateCheck = check;
    unawaited(
      check.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (identical(_activeUpdateCheck, check)) {
          _activeUpdateCheck = null;
        }
      }),
    );
    return check;
  }

  void _applyBadAppScanResult(BadAppScanResult result) {
    badAppFindings = result.findings;
    badAppScannedAt = result.scannedAt;
    badAppScanFailed = false;
    badAppScanRanThisSession = true;
  }

  void _setBusy(
    bool value, {
    String? statusKey,
    bool clearError = false,
    bool clearWarning = false,
  }) {
    if (_disposed) {
      return;
    }

    isBusy = value;
    if (statusKey != null) {
      busyStatusText = statusKey;
    }
    if (clearError) {
      errorMessage = null;
    }
    if (clearWarning) {
      warningMessage = null;
    }
    notifyListeners();
  }

  void _applyProfile(ClientProfile profile) {
    userIdController.text = profile.userId;
    tunNameController.text = profile.tunName;
    dnsController.text = profile.dnsServers.join(', ');
    failbackDelayController.text = '${profile.serverFailbackDelaySec}';
    metricsWindowController.text = '${profile.metrics.windowSeconds}';
    metricsFileDirController.text = profile.metrics.fileDir;
    tunnelMtuController.text = '${profile.tunnelMtu}';
    packetFragmentPayloadController.text =
        '${profile.packetFragmentPayloadBytes}';
    transportMode = profile.transport.mode;
    networkRescueProfile = profile.networkRescue.profile;
    metricsEnabled = profile.metrics.enabled;
    metricsFileEnabled = profile.metrics.fileEnabled;
    prestartFullProbe = profile.prestartFullProbe;
    steadyStateQuickProbeEnabled = profile.steadyStateQuickProbeEnabled;
    steadyStateBenchmarkEnabled = profile.steadyStateBenchmarkEnabled;
    disableIpv6 = profile.disableIpv6;
    tunnelMtu = profile.tunnelMtu;
    packetFragmentPayloadBytes = profile.packetFragmentPayloadBytes;
    disablePacketBatching = profile.disablePacketBatching;
    relays = profile.relays;
    servers = _normalizeServerPriorities(profile.servers);
    windowsApps = _normalizeWindowsApps(profile.windowsApps);
    profileAndroidApps = _normalizeWindowsApps(profile.androidApps);
    profileExtraFields = profile.extraFields;
    transportExtraFields = profile.transport.extraFields;
    networkRescueExtraFields = profile.networkRescue.extraFields;
    metricsExtraFields = profile.metrics.extraFields;
    splitTunnelExtraFields = profile.splitTunnelExtraFields;
    splitTunnelMode = profile.splitTunnelMode;
  }

  void _applyLaunchResult(LaunchResult result) {
    if (result.success) {
      _setRuntimeStarted(true);
      statusMessage = result.message;
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

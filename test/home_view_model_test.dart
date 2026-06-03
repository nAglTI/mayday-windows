import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mayday_windows/core/l10n/app_texts.dart';
import 'package:mayday_windows/core/models/bad_app_finding.dart';
import 'package:mayday_windows/core/models/network_rescue_config.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/app_autostart_service.dart';
import 'package:mayday_windows/core/services/app_update_service.dart';
import 'package:mayday_windows/core/services/bad_app_scan_result_storage.dart';
import 'package:mayday_windows/core/services/bad_app_scanner_service.dart';
import 'package:mayday_windows/core/services/client_profile_storage.dart';
import 'package:mayday_windows/core/services/runtime_diagnostics_logger.dart';
import 'package:mayday_windows/core/services/runtime_launcher.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:mayday_windows/core/services/tray_icon_service.dart';
import 'package:mayday_windows/features/home/application/client_controller.dart';
import 'package:mayday_windows/features/home/presentation/home_view_model.dart';

void main() {
  const userKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('bootstrap refreshes bad app scan result in the background', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final scanner = _FakeBadAppScannerService(
      findings: const [_blockedFinding],
      release: Completer<void>(),
    );
    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: scanner,
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    final bootstrapFuture = viewModel.bootstrap();
    await scanner.started.future.timeout(const Duration(seconds: 3));

    expect(viewModel.isBusy, isFalse);
    expect(viewModel.badAppFindings, isNull);
    expect(scanner.scanCount, 1);

    scanner.release?.complete();
    await bootstrapFuture;
    await _waitUntil(() => viewModel.badAppFindings != null);

    expect(viewModel.badAppFindings, [_blockedFinding]);
    expect(scanner.scanCount, 1);
  });

  test('foreground scan reuses an active session background scan', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final scanner = _FakeBadAppScannerService(
      findings: const [],
      release: Completer<void>(),
    );
    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: scanner,
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    final bootstrapFuture = viewModel.bootstrap();
    await scanner.started.future.timeout(const Duration(seconds: 3));

    final scanFuture = viewModel.scanBadAppFindings();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isBusy, isTrue);
    expect(scanner.scanCount, 1);

    scanner.release?.complete();
    final findings = await scanFuture;
    await bootstrapFuture;

    expect(findings, isEmpty);
    expect(viewModel.badAppFindings, isEmpty);
    expect(viewModel.isBadAppPreflightPassed, isTrue);
    expect(scanner.scanCount, 1);
  });

  test('foreground scan findings warn but do not mark launch as blocked',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: _FakeBadAppScannerService(findings: const [_blockedFinding]),
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    final findings = await viewModel.scanBadAppFindings();

    expect(findings, [_blockedFinding]);
    expect(viewModel.badAppFindings, [_blockedFinding]);
    expect(viewModel.isBadAppPreflightPassed, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.warningMessage, contains('Blocked apps were found: 1'));
  });

  test('failed foreground scan marks preflight as failed', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: _FakeBadAppScannerService(
        findings: const [],
        error: StateError('scanner unavailable'),
      ),
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    final findings = await viewModel.scanBadAppFindings();

    expect(findings, isNull);
    expect(viewModel.badAppScanFailed, isTrue);
    expect(viewModel.isBadAppPreflightPassed, isFalse);
    expect(viewModel.badAppScanSummary, 'scan failed');
    expect(viewModel.errorMessage, contains('scanner unavailable'));
  });

  test('bootstrap exposes newer release as dismissible update banner',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: _FakeBadAppScannerService(findings: const []),
      launcher: launcher,
      updateService: AppUpdateService(
        releaseLoader: () async => const GitHubRelease(
          tagName: 'v9.0.0',
          name: 'Mayday 9.0.0',
          htmlUrl:
              'https://github.com/nAglTI/mayday-windows/releases/tag/v9.0.0',
          draft: false,
          prerelease: false,
        ),
      ),
    );
    addTearDown(viewModel.dispose);

    await viewModel.bootstrap();
    await _waitUntil(
      () =>
          viewModel.availableUpdate != null && viewModel.badAppFindings != null,
    );

    expect(viewModel.shouldShowUpdateBanner, isTrue);
    expect(viewModel.availableUpdate!.latestVersion.displayVersion, '9.0.0');

    viewModel.dismissAvailableUpdate();

    expect(viewModel.shouldShowUpdateBanner, isFalse);
  });

  test('bootstrap warns when saved profile uses legacy core contract',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final runtimePathsService = _FakeRuntimePathsService(tempDir.path);
    final paths = await runtimePathsService.getPaths();
    await Directory(paths.configDir).create(recursive: true);
    await File(p.join(paths.configDir, 'client.yaml')).writeAsString('''
user_id: 1
relays:
  - id: "relay-abobus"
    addr: "1.2.3.4:51821"
    short_id: 1
    ports: [51821]
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: false
  mode: whitelist
  apps_win: []
  apps_android: []
''');

    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: _FakeBadAppScannerService(findings: const []),
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    await viewModel.bootstrap();
    await _waitUntil(() => viewModel.badAppFindings != null);

    expect(viewModel.userIdController.text, isEmpty);
    expect(
      viewModel.warningMessage,
      const AppTextCatalog(
        AppLanguage.english,
      ).t('message.saved_config_incompatible'),
    );
  });

  test('addSplitTunnelApps adds multiple unique Windows app paths', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-home-vm-');
    addTearDown(() => tempDir.delete(recursive: true));

    final launcher = _FakeRuntimeLauncher();
    addTearDown(launcher.dispose);

    final viewModel = _createViewModel(
      root: tempDir.path,
      scanner: _FakeBadAppScannerService(findings: const []),
      launcher: launcher,
    );
    addTearDown(viewModel.dispose);

    viewModel.addSplitTunnelApps([
      r'C:\Apps\One.exe',
      r'C:\Apps\Two.exe',
      r'c:\apps\one.exe',
    ]);

    expect(viewModel.windowsApps, [
      r'C:\Apps\One.exe',
      r'C:\Apps\Two.exe',
    ]);
    expect(viewModel.statusMessage, 'Added 2 split apps');

    viewModel.addSplitTunnelApps([
      r'C:\Apps\Two.exe',
      r'C:\Apps\Three.exe',
    ]);

    expect(viewModel.windowsApps, [
      r'C:\Apps\One.exe',
      r'C:\Apps\Two.exe',
      r'C:\Apps\Three.exe',
    ]);
    expect(viewModel.statusMessage, 'Added split app: Three.exe');
  });

  test('imports and edits current runtime protection fields', () async {
    final viewModel = HomeViewModel(
      controller: ClientController(),
      textCatalog: const AppTextCatalog(AppLanguage.english),
      trayIconService: const _FakeTrayIconService(),
    );
    addTearDown(viewModel.dispose);

    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: https
network_rescue:
  enabled: true
  profile: stable
prestart_full_probe: true
steady_state_quick_probe_enabled: true
steady_state_benchmark_enabled: true
disable_ipv6: true
tunnel_mtu: 100
packet_fragment_payload_bytes: 100
disable_packet_batching: true
metrics:
  enabled: true
  window_seconds: 600
  file_enabled: true
  file_dir: "./metrics"
discovery_relays:
  - id: "relay-main"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821]
      ws: [51822]
      https-rest: [443]
      bt-tcp: [51823]
      raw-udp: [51824]
servers:
  - id: "exit-main"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: false
  apps_mode: whitelist
  apps_win: []
  apps_android: []
''';

    await viewModel.importConfigFromKey(base64Url.encode(utf8.encode(raw)));

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.networkRescueProfile, NetworkRescueProfile.stable);
    expect(viewModel.prestartFullProbe, isTrue);
    expect(viewModel.steadyStateQuickProbeEnabled, isTrue);
    expect(viewModel.steadyStateBenchmarkEnabled, isTrue);
    expect(viewModel.disableIpv6, isTrue);
    expect(viewModel.tunnelMtuController.text, '100');
    expect(viewModel.packetFragmentPayloadController.text, '100');
    expect(viewModel.disablePacketBatching, isTrue);
    expect(viewModel.metricsEnabled, isFalse);

    viewModel.setPacketFragmentPayloadBytes(512);
    viewModel.setNetworkRescueProfile(NetworkRescueProfile.extreme);
    viewModel.setMetricsEnabled(true);
    viewModel.tunnelMtuController.text = '1500';
    final profile = viewModel.collectProfile();

    expect(profile.transport.mode.name, 'https');
    expect(profile.networkRescue.profile, NetworkRescueProfile.extreme);
    expect(profile.tunnelMtu, 1500);
    expect(profile.packetFragmentPayloadBytes, 512);
    expect(profile.disablePacketBatching, isTrue);
    expect(profile.metrics.enabled, isTrue);
    expect(profile.metrics.fileEnabled, isFalse);
    expect(profile.metrics.fileDir, isEmpty);
  });
}

HomeViewModel _createViewModel({
  required String root,
  required BadAppScannerService scanner,
  required RuntimeLauncher launcher,
  AppUpdateService? updateService,
}) {
  final runtimePathsService = _FakeRuntimePathsService(root);
  final textCatalog = const AppTextCatalog(AppLanguage.english);
  final controller = ClientController(
    runtimePathsService: runtimePathsService,
    storage: ClientProfileStorage(
      runtimePathsService: runtimePathsService,
      textCatalog: textCatalog,
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
    ),
    launcher: launcher,
    badAppScannerService: scanner,
    badAppScanResultStorage: BadAppScanResultStorage(
      runtimePathsService: runtimePathsService,
    ),
    appUpdateService:
        updateService ?? AppUpdateService(releaseLoader: () async => null),
    appSettings: AppLanguageSettings(
      runtimePathsService: runtimePathsService,
    ),
    autostartService: const _FakeAppAutostartService(),
    appTextCatalog: textCatalog,
  );

  return HomeViewModel(
    controller: controller,
    textCatalog: textCatalog,
    trayIconService: const _FakeTrayIconService(),
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

const _blockedFinding = BadAppFinding(
  category: 'installed_app',
  name: 'Blocked App',
  path: r'C:\Apps\Blocked.exe',
  publisher: 'Blocked Publisher',
  version: '1.0.0',
  status: 'installed',
  state: 'present',
  matchedKeywords: ['blocked'],
);

class _FakeBadAppScannerService extends BadAppScannerService {
  _FakeBadAppScannerService({
    required this.findings,
    this.release,
    this.error,
  });

  final List<BadAppFinding> findings;
  final Completer<void>? release;
  final Object? error;
  final started = Completer<void>();
  int scanCount = 0;

  @override
  Future<List<BadAppFinding>> scan() async {
    scanCount += 1;
    if (!started.isCompleted) {
      started.complete();
    }
    await release?.future;
    final scanError = error;
    if (scanError != null) {
      throw scanError;
    }
    return findings;
  }
}

class _FakeAppAutostartService extends AppAutostartService {
  const _FakeAppAutostartService();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FakeRuntimeLauncher extends RuntimeLauncher {
  final _runningChanges = StreamController<bool>.broadcast();

  @override
  bool get isRunning => false;

  @override
  Stream<bool> get runningChanges => _runningChanges.stream;

  @override
  Future<StopResult> shutdown() async {
    return const StopResult(success: true, message: 'stopped');
  }

  void dispose() {
    _runningChanges.close();
  }
}

class _FakeTrayIconService extends TrayIconService {
  const _FakeTrayIconService();

  @override
  Future<void> setVpnConnected(bool connected) async {}
}

class _FakeRuntimePathsService extends RuntimePathsService {
  const _FakeRuntimePathsService(this.root);

  final String root;

  @override
  Future<RuntimePaths> getPaths() async {
    final configDir = p.join(root, 'config');
    return RuntimePaths(
      installRoot: root,
      runtimeDir: p.join(root, 'runtime'),
      clientExePath: p.join(root, 'runtime', 'mdhelper.exe'),
      pipeHelperExePath: p.join(root, 'runtime', 'mdpipectl.exe'),
      mutableRoot: root,
      configDir: configDir,
      configPath: p.join(configDir, 'client.yaml.dpapi'),
    );
  }
}

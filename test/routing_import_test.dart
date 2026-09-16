import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/l10n/app_texts.dart';
import 'package:mayday_windows/core/models/app_update_info.dart';
import 'package:mayday_windows/core/models/bad_app_scan_result.dart';
import 'package:mayday_windows/core/models/client_profile.dart';
import 'package:mayday_windows/core/models/relay_target.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/models/runtime_status_snapshot.dart';
import 'package:mayday_windows/core/models/server_target.dart';
import 'package:mayday_windows/core/models/split_tunnel_mode.dart';
import 'package:mayday_windows/core/models/transport_config.dart';
import 'package:mayday_windows/core/services/client_profile_codec.dart';
import 'package:mayday_windows/core/services/client_profile_storage.dart';
import 'package:mayday_windows/core/services/app_autostart_service.dart';
import 'package:mayday_windows/core/services/bad_app_scan_result_storage.dart';
import 'package:mayday_windows/core/services/profile_encryption_service.dart';
import 'package:mayday_windows/core/services/runtime_diagnostics_logger.dart';
import 'package:mayday_windows/core/services/runtime_launcher.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:mayday_windows/core/services/tray_icon_service.dart';
import 'package:mayday_windows/features/home/application/client_controller.dart';
import 'package:mayday_windows/features/home/presentation/home_view_model.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first import applies routing supplied by the key', () async {
    final viewModel = _createViewModel();
    final incoming = _profile(
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Incoming.exe'],
      androidApps: ['com.example.incoming'],
      splitExtras: {'future_rule': 'incoming'},
    );

    await viewModel.importConfigFromKey(_importKey(incoming));

    expect(viewModel.errorMessage, isNull);
    _expectRouting(viewModel.collectProfile(), incoming);
  });

  test('equal exit priorities retain array order and keys when reordered',
      () async {
    final viewModel = _createViewModel();
    final servers = [
      ServerTarget(id: 'z-first', key: '1' * 64, priority: 1),
      ServerTarget(id: 'a-second', key: '2' * 64, priority: 1),
      ServerTarget(id: 'm-third', key: '3' * 64, priority: 2),
    ];
    await viewModel.importConfigFromKey(
      _importKey(_profile().copyWith(servers: servers)),
    );

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.servers.map((server) => server.id),
        ['z-first', 'a-second', 'm-third']);
    viewModel.reorderServers(2, 0);
    final exported = const ClientProfileCodec().parseCurrentContractRaw(
      const ClientProfileCodec().encodeRuntimeYaml(viewModel.collectProfile()),
    );
    expect(exported.servers.map((server) => server.id),
        ['m-third', 'z-first', 'a-second']);
    expect(exported.servers.map((server) => server.priority), [1, 2, 3]);
    expect(
      {for (final server in exported.servers) server.id: server.key},
      {for (final server in servers) server.id: server.key},
    );
  });

  test('omitted and zero exit priorities rank ahead of explicit priority one',
      () async {
    final viewModel = _createViewModel();
    final raw = <String, Object?>{
      'config_version': 1,
      'user_id': 1,
      'transport': {'mode': 'ws'},
      'discovery_relays': [
        {
          'id': 'relay-test',
          'addr': 'relay.example.test',
          'relay_key': '4' * 64,
          'transport_ports': {
            'ws': [443]
          },
        },
      ],
      'servers': [
        {'id': 'a-priority-one', 'key': '1' * 64, 'priority': 1},
        {'id': 'z-omitted', 'key': '2' * 64},
        {'id': 'b-zero', 'key': '3' * 64, 'priority': 0},
      ],
    };
    final parsed =
        const ClientProfileCodec().parseCurrentContractRaw(jsonEncode(raw));
    expect(parsed.servers.map((server) => server.priority), [1, 0, 0]);

    await viewModel.importConfigFromKey(
      base64Url.encode(utf8.encode(jsonEncode(raw))),
    );

    expect(viewModel.errorMessage, isNull);
    final profile = viewModel.collectProfile();
    expect(profile.servers.map((server) => server.id),
        ['z-omitted', 'b-zero', 'a-priority-one']);
    expect(profile.servers.map((server) => server.priority), [1, 2, 3]);
    expect(profile.servers.map((server) => server.key),
        ['2' * 64, '3' * 64, '1' * 64]);
  });

  for (final mode in SplitTunnelMode.values) {
    test('replacement key preserves existing ${mode.name} routing', () async {
      final viewModel = _createViewModel();
      final existing = _profile(
        mode: mode,
        windowsApps: [r'C:\Apps\Existing.exe'],
        androidApps: ['com.example.existing'],
        splitExtras: {
          'future_rule': 'local',
          'local_rule': ['keep'],
        },
      );
      final incoming = _profile(
        userId: '2',
        mode: SplitTunnelMode.onlySelected,
        windowsApps: [r'C:\Apps\Incoming.exe'],
        androidApps: ['com.example.incoming'],
        splitExtras: {'future_rule': 'incoming', 'new_rule': true},
      );

      await viewModel.importConfigFromKey(_importKey(existing));
      await viewModel.importConfigFromKey(_importKey(incoming));

      expect(viewModel.errorMessage, isNull);
      final migrated = viewModel.collectProfile();
      _expectRouting(
        migrated,
        existing.copyWith(
          splitTunnelExtraFields: {
            ...existing.splitTunnelExtraFields,
            'new_rule': true,
          },
        ),
      );
      expect(migrated.userId, incoming.userId);
      expect(migrated.servers.single.id, incoming.servers.single.id);
      expect(migrated.servers.single.key, incoming.servers.single.key);
      expect(migrated.relays.single.addr, incoming.relays.single.addr);
      expect(migrated.relays.single.relayKey, incoming.relays.single.relayKey);
      expect(migrated.transport.mode, TransportMode.rawUdpV2);
    });
  }

  test('replacement preserves intentionally disabled routing with no apps',
      () async {
    final viewModel = _createViewModel();
    final existing = _profile();
    await viewModel.importConfigFromKey(_importKey(existing));

    await viewModel.importConfigFromKey(_importKey(_profile(
      userId: '2',
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Incoming.exe'],
    )));

    expect(viewModel.errorMessage, isNull);
    _expectRouting(viewModel.collectProfile(), existing);
    expect(viewModel.userIdController.text, '2');
  });

  test('replacement uses unsaved routing edits including removed apps',
      () async {
    final viewModel = _createViewModel();
    await viewModel.importConfigFromKey(_importKey(_profile(
      mode: SplitTunnelMode.onlySelected,
      windowsApps: [r'C:\Apps\Remove.exe', r'C:\Apps\Keep.exe'],
    )));
    viewModel.setSplitTunnelMode(SplitTunnelMode.excludeSelected);
    viewModel.removeSplitTunnelApp(r'C:\Apps\Remove.exe');
    viewModel.addSplitTunnelApps([
      r'C:\Apps\New.exe',
      r'c:\apps\new.exe',
    ]);

    await viewModel.importConfigFromKey(_importKey(_profile(userId: '2')));

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.splitTunnelMode, SplitTunnelMode.excludeSelected);
    expect(viewModel.windowsApps, [r'C:\Apps\Keep.exe', r'C:\Apps\New.exe']);
  });

  test('first import preserves routing explicitly edited before a key exists',
      () async {
    final viewModel = _createViewModel();
    viewModel.addSplitTunnelApp(r'C:\Apps\Local.exe');
    viewModel.setSplitTunnelMode(SplitTunnelMode.excludeSelected);

    await viewModel.importConfigFromKey(_importKey(_profile(
      mode: SplitTunnelMode.onlySelected,
      windowsApps: [r'C:\Apps\Incoming.exe'],
    )));

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.splitTunnelMode, SplitTunnelMode.excludeSelected);
    expect(viewModel.windowsApps, [r'C:\Apps\Local.exe']);
  });

  test('explicit disabled choice before first import remains disabled',
      () async {
    final viewModel = _createViewModel();
    viewModel.setSplitTunnelMode(SplitTunnelMode.disabled);

    await viewModel.importConfigFromKey(_importKey(_profile(
      mode: SplitTunnelMode.onlySelected,
      windowsApps: [r'C:\Apps\Incoming.exe'],
    )));

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.splitTunnelMode, SplitTunnelMode.disabled);
    expect(viewModel.windowsApps, isEmpty);
  });

  test('invalid replacement leaves routing and current profile intact',
      () async {
    final viewModel = _createViewModel();
    await viewModel.importConfigFromKey(_importKey(_profile(
      mode: SplitTunnelMode.onlySelected,
      windowsApps: [r'C:\Apps\Keep.exe'],
    )));
    final before =
        const ClientProfileCodec().encodeYaml(viewModel.collectProfile());

    await viewModel.importConfigFromKey('not a valid access key');

    expect(viewModel.errorMessage, isNotNull);
    expect(const ClientProfileCodec().encodeYaml(viewModel.collectProfile()),
        before);
    expect(viewModel.isBusy, isFalse);

    await viewModel.importConfigFromKey(
      base64Url.encode(utf8.encode('config_version: 999')),
    );

    expect(viewModel.errorMessage, isNotNull);
    expect(const ClientProfileCodec().encodeYaml(viewModel.collectProfile()),
        before);
  });

  test('saved routing migrates after bootstrap and survives save and reload',
      () async {
    final directory = await Directory.systemTemp.createTemp('routing_import_');
    addTearDown(() => directory.delete(recursive: true));
    final pathService = _TestPathsService(directory.path);
    final storage = ClientProfileStorage(
      runtimePathsService: pathService,
      encryptionService: const _TestEncryptionService(),
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
    );
    final existing = _profile(
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Saved.exe'],
      androidApps: ['com.example.saved'],
      splitExtras: {
        'future_rule': {'enabled': true}
      },
    );
    await storage.saveProfile(existing);
    final viewModel = _createViewModel(
      storage: storage,
      bootstrapLoader: () async => BootstrapState(
        profile: (await storage.loadSavedProfileForCurrentContract())!,
        paths: await pathService.getPaths(),
        missingRuntimeFiles: const [],
        autoStartEnabled: false,
      ),
    );
    await viewModel.bootstrap();
    expect(viewModel.errorMessage, isNull);

    await viewModel.importConfigFromKey(_importKey(_profile(userId: '2')));
    await viewModel.saveProfile();

    expect(viewModel.errorMessage, isNull);
    final reloaded = (await storage.loadSavedProfileForCurrentContract())!;
    _expectRouting(reloaded, existing);
    expect(reloaded.userId, '2');
    expect(reloaded.transport.mode, TransportMode.rawUdpV2);
    final runtime = const ClientProfileCodec().parseCurrentContractRaw(
      const ClientProfileCodec().encodeRuntimeYaml(reloaded),
    );
    _expectRouting(runtime, existing);
  });

  test('removed raw UDP saved profile keeps routing when a new key replaces it',
      () async {
    final directory = await Directory.systemTemp.createTemp('routing_raw_');
    addTearDown(() => directory.delete(recursive: true));
    final pathService = _TestPathsService(directory.path);
    final storage = ClientProfileStorage(
      runtimePathsService: pathService,
      encryptionService: const _TestEncryptionService(),
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
    );
    final existing = _profile(
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Saved.exe'],
      androidApps: ['com.example.saved'],
      splitExtras: {'local_rule': 'keep'},
    ).copyWith(transport: const TransportConfig(mode: TransportMode.rawUdp));
    await storage.saveProfile(existing);
    final viewModel = _createViewModel(
      storage: storage,
      runtimePathsService: pathService,
    );

    await viewModel.bootstrap();

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.warningMessage, contains('Raw UDP v1 was removed'));
    expect(viewModel.transportMode, TransportMode.rawUdp);
    _expectRouting(viewModel.collectProfile(), existing);
    expect(
        () => const ClientProfileCodec()
            .encodeRuntimeYaml(viewModel.collectProfile()),
        throwsA(isA<LegacyRawUdpProfileException>()));

    await viewModel.importConfigFromKey(_importKey(_profile(userId: '2')));
    await viewModel.saveProfile();

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.warningMessage, isNull);
    final migrated = (await storage.loadSavedProfileForCurrentContract())!;
    _expectRouting(migrated, existing);
    expect(migrated.transport.mode, TransportMode.rawUdpV2);
    expect(migrated.userId, '2');
  });

  test('removed raw UDP in incompatible metadata is not recovered', () async {
    final directory = await Directory.systemTemp.createTemp('routing_raw_');
    addTearDown(() => directory.delete(recursive: true));
    final pathService = _TestPathsService(directory.path);
    final storage = ClientProfileStorage(
      runtimePathsService: pathService,
      encryptionService: const _TestEncryptionService(),
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
    );
    await storage.saveProfile(_profile(
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Saved.exe'],
    ).copyWith(transport: const TransportConfig(mode: TransportMode.rawUdp)));
    final paths = await pathService.getPaths();
    await File(p.join(paths.configDir, 'client_profile_metadata.json'))
        .writeAsString(jsonEncode({'contractVersion': 4}));
    final viewModel = _createViewModel(
      storage: storage,
      runtimePathsService: pathService,
    );

    await viewModel.bootstrap();

    expect(viewModel.userIdController.text, isEmpty);
    expect(viewModel.windowsApps, isEmpty);
    expect(
        viewModel.warningMessage,
        const AppTextCatalog(AppLanguage.english)
            .t('message.saved_config_incompatible'));
  });

  test('new removed raw UDP key gives a clear error without changing routing',
      () async {
    final viewModel = _createViewModel();
    final existing = _profile(
      mode: SplitTunnelMode.excludeSelected,
      windowsApps: [r'C:\Apps\Keep.exe'],
    );
    await viewModel.importConfigFromKey(_importKey(existing));
    final removed = _profile(userId: '2').copyWith(
      transport: const TransportConfig(mode: TransportMode.rawUdp),
    );

    await viewModel.importConfigFromKey(_importKey(removed));

    expect(viewModel.errorMessage, contains('Raw UDP v1 was removed'));
    expect(viewModel.userIdController.text, '1');
    _expectRouting(viewModel.collectProfile(), existing);
  });
}

HomeViewModel _createViewModel({
  ClientProfileStorage? storage,
  RuntimePathsService? runtimePathsService,
  Future<BootstrapState> Function()? bootstrapLoader,
}) {
  final viewModel = HomeViewModel(
    controller: _TestClientController(
      storage: storage,
      runtimePathsService: runtimePathsService,
      bootstrapLoader: bootstrapLoader,
    ),
    textCatalog: const AppTextCatalog(AppLanguage.english),
    trayIconService: const _TestTrayIconService(),
  );
  addTearDown(viewModel.dispose);
  return viewModel;
}

ClientProfile _profile({
  String userId = '1',
  SplitTunnelMode mode = SplitTunnelMode.disabled,
  List<String> windowsApps = const [],
  List<String> androidApps = const [],
  Map<String, Object?> splitExtras = const {},
}) {
  final key = userId == '1' ? '1' * 64 : '2' * 64;
  return ClientProfile(
    userId: userId,
    relays: [
      RelayTarget(
        id: 'relay-$userId',
        addr: 'relay-$userId.example.test',
        shortId: 1,
        relayKey: key,
        transportPorts: const {
          'https-rest': [443],
          'raw-udp-v2': [51825],
        },
      ),
    ],
    servers: [ServerTarget(id: 'exit-$userId', key: key, priority: 1)],
    transport: TransportConfig(
      mode: userId == '1' ? TransportMode.https : TransportMode.rawUdpV2,
    ),
    splitTunnelMode: mode,
    windowsApps: windowsApps,
    androidApps: androidApps,
    splitTunnelExtraFields: splitExtras,
  );
}

String _importKey(ClientProfile profile) {
  return base64Url
      .encode(utf8.encode(const ClientProfileCodec().encodeYaml(profile)));
}

void _expectRouting(ClientProfile actual, ClientProfile expected) {
  expect(actual.splitTunnelMode, expected.splitTunnelMode);
  expect(actual.windowsApps, expected.windowsApps);
  expect(actual.androidApps, expected.androidApps);
  expect(actual.splitTunnelExtraFields, expected.splitTunnelExtraFields);
}

class _TestClientController extends ClientController {
  _TestClientController({
    super.storage,
    super.runtimePathsService,
    this.bootstrapLoader,
  }) : super(
          appSettings:
              AppLanguageSettings(runtimePathsService: runtimePathsService),
          autostartService: const _TestAutostartService(),
          badAppScanResultStorage: BadAppScanResultStorage(
            runtimePathsService: runtimePathsService,
          ),
        );

  final Future<BootstrapState> Function()? bootstrapLoader;

  @override
  Future<BootstrapState> bootstrap() =>
      bootstrapLoader?.call() ?? super.bootstrap();

  @override
  bool get isRunning => false;

  @override
  Stream<bool> get runningChanges => const Stream<bool>.empty();

  @override
  Stream<RuntimeStatusSnapshot> get runtimeStatusChanges =>
      const Stream<RuntimeStatusSnapshot>.empty();

  @override
  Future<StopResult> shutdownRuntime() async =>
      const StopResult(success: true, message: 'stopped');

  @override
  Future<BadAppScanResult> scanBadAppFindings() async => BadAppScanResult(
        scannedAt: DateTime.utc(2026, 1, 1),
        findings: const [],
      );

  @override
  Future<AppUpdateInfo?> checkForUpdate() async => null;
}

class _TestAutostartService extends AppAutostartService {
  const _TestAutostartService();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _TestTrayIconService extends TrayIconService {
  const _TestTrayIconService();

  @override
  Future<void> setVpnConnected(bool connected) async {}
}

class _TestEncryptionService extends ProfileEncryptionService {
  const _TestEncryptionService();

  @override
  Future<String> encrypt(String plainText) async =>
      base64Encode(utf8.encode(plainText));

  @override
  Future<String> decrypt(String encryptedText) async =>
      utf8.decode(base64Decode(encryptedText));
}

class _TestPathsService extends RuntimePathsService {
  const _TestPathsService(this.root);

  final String root;

  @override
  Future<RuntimePaths> getPaths() async => RuntimePaths(
        installRoot: root,
        runtimeDir: p.join(root, 'runtime'),
        clientExePath: p.join(root, 'runtime', 'mdhelper.exe'),
        mutableRoot: root,
        configDir: p.join(root, 'config'),
        configPath: p.join(root, 'config', 'client.yaml.dpapi'),
      );
}

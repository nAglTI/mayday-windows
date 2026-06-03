import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/network_rescue_config.dart';
import 'package:mayday_windows/core/models/transport_config.dart';
import 'package:path/path.dart' as p;
import 'package:mayday_windows/core/l10n/app_texts.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/client_profile_codec.dart';
import 'package:mayday_windows/core/services/client_profile_storage.dart';
import 'package:mayday_windows/core/services/profile_encryption_service.dart';
import 'package:mayday_windows/core/services/runtime_diagnostics_logger.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:mayday_windows/features/home/application/client_controller.dart';
import 'package:mayday_windows/features/home/presentation/home_view_model.dart';

void main() {
  const userKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('imports current config and exports minimal discovery config', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
server_failback_delay_sec: 60
future_top: "kept"

transport:
  mode: tcp
  future_transport: true

network_rescue:
  enabled: true
  profile: extreme
  future_rescue: "kept"

metrics:
  enabled: true
  window_seconds: 600
  file_enabled: true
  file_dir: "./metrics"
  future_metrics: "kept"

discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821, 51822]
      ws: [51823]
      https-rest: [443]
      bt-tcp: [51824]
      raw-udp: [51825]
    future_relay: "kept"

servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
    future_server: "kept"

split_tunnel:
  enabled: true
  mode: whitelist
  apps_win: ["C:/Apps/App.exe"]
  apps_android: ["com.example.app"]
  future_split: "kept"
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.relays.single.transportPorts['bt-utp'], [51821, 51822]);
    expect(profile.relays.single.transportPorts['https-rest'], [443]);
    expect(profile.relays.single.transportPorts['raw-udp'], [51825]);
    expect(profile.networkRescue.profile, NetworkRescueProfile.extreme);
    expect(profile.metrics.fileDir, './metrics');
    expect(encoded, contains('discovery_relays:'));
    expect(encoded, contains('transport_ports:'));
    expect(encoded, contains('bt-utp: [51821, 51822]'));
    expect(encoded, contains('https-rest: [443]'));
    expect(encoded, contains('server_failback_delay_sec: 60'));
    expect(encoded, contains('split_tunnel:'));
    expect(encoded, contains('future_top: \'kept\''));
    expect(encoded, contains('future_transport: true'));
    expect(encoded, contains('network_rescue:'));
    expect(encoded, contains('enabled: true'));
    expect(encoded, contains('profile: \'extreme\''));
    expect(encoded, contains('future_rescue: \'kept\''));
    expect(encoded, contains('metrics:'));
    expect(encoded, contains('future_metrics: \'kept\''));
    expect(encoded, contains('future_relay: \'kept\''));
    expect(encoded, contains('future_server: \'kept\''));
    expect(encoded, contains('future_split: \'kept\''));
    expect(encoded, isNot(contains('tun_name:')));
    expect(encoded, isNot(contains('dns:')));
    expect(encoded, contains('apps_mode: \'whitelist\''));
    expect(encoded, isNot(contains('\nrelays:')));
    expect(encoded, isNot(contains('\n    ports:')));
    expect(encoded, isNot(contains('relay_mode')));
    expect(encoded, isNot(contains('slot_start')));
    expect(encoded, isNot(contains('streams')));
  });

  test('form state preserves unknown imported fields', () async {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
server_failback_delay_sec: 60
future_top: "kept"
transport:
  mode: tcp
  future_transport: true
network_rescue:
  enabled: true
  profile: stable
  future_rescue: "kept"
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 100
disable_packet_batching: true
metrics:
  enabled: true
  window_seconds: 600
  file_enabled: true
  file_dir: "./metrics"
  future_metrics: "kept"
discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821, 51822]
      ws: [51823]
      https-rest: [443]
      bt-tcp: [51824]
      raw-udp: [51825]
    future_relay: "kept"
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
    future_server: "kept"
split_tunnel:
  enabled: true
  apps_mode: whitelist
  apps_win: ["C:/Apps/App.exe"]
  apps_android: []
  future_split: "kept"
''';

    const codec = ClientProfileCodec();
    final viewModel = HomeViewModel(
      controller: ClientController(codec: codec),
      textCatalog: const AppTextCatalog(AppLanguage.english),
    );
    addTearDown(viewModel.dispose);

    await viewModel.importConfigFromKey(base64Url.encode(utf8.encode(raw)));
    expect(viewModel.errorMessage, isNull);

    final encoded = codec.encodeYaml(viewModel.collectProfile());
    expect(encoded, contains('future_top: \'kept\''));
    expect(encoded, contains('future_transport: true'));
    expect(encoded, contains('future_rescue: \'kept\''));
    expect(encoded, contains('profile: \'stable\''));
    expect(encoded, contains('future_metrics: \'kept\''));
    expect(encoded, contains('packet_fragment_payload_bytes: 100'));
    expect(encoded, contains('disable_packet_batching: true'));
    expect(encoded, contains('future_relay: \'kept\''));
    expect(encoded, contains('future_server: \'kept\''));
    expect(encoded, contains('future_split: \'kept\''));
  });

  test('imports and exports discovery relays with relay keys', () {
    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: auto
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
discovery_relays:
  - id: "relay-main"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821, 51822]
      ws: [51823]
      https-rest: [443]
      bt-tcp: [51824]
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

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.relays.single.id, 'relay-main');
    expect(encoded, contains('discovery_relays:'));
    expect(encoded, contains('relay_key: \'$userKey\''));
    expect(encoded, contains('transport_ports:'));
    expect(encoded, contains('prestart_full_probe: false'));
    expect(encoded, isNot(contains('\nrelays:')));
  });

  test('imports and exports https transport mode', () {
    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: https
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
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

    const codec = ClientProfileCodec();
    final profile = codec.parseCurrentContractRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.transport.mode.name, 'https');
    expect(TransportMode.fromWireValue('https-rest'), TransportMode.https);
    expect(TransportMode.fromWireValue('rest'), TransportMode.https);
    expect(TransportMode.fromWireValue('bt-tcp'), TransportMode.tcp);
    expect(TransportMode.fromWireValue('bt-utp'), TransportMode.utp);
    expect(TransportMode.fromWireValue('raw-udp'), TransportMode.rawUdp);
    expect(TransportMode.fromWireValue('rawudp'), TransportMode.rawUdp);
    expect(TransportMode.fromWireValue('udp'), TransportMode.rawUdp);
    expect(TransportMode.supportsWireValue('icmp-echo'), isFalse);
    expect(encoded, contains("mode: 'https'"));
    expect(encoded, contains('https-rest: [443]'));
  });

  test('imports and exports raw udp transport and rescue profile', () {
    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: raw-udp
network_rescue:
  enabled: true
  profile: extreme
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
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

    const codec = ClientProfileCodec();
    final profile = codec.parseCurrentContractRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.transport.mode, TransportMode.rawUdp);
    expect(profile.networkRescue.profile, NetworkRescueProfile.extreme);
    expect(profile.networkRescue.enabled, isTrue);
    expect(encoded, contains("mode: 'udp'"));
    expect(encoded, contains('raw-udp: [51824]'));
    expect(encoded, contains('network_rescue:'));
    expect(encoded, contains('enabled: true'));
    expect(encoded, contains("profile: 'extreme'"));
  });

  test('rejects removed icmp transport and legacy relay ports', () {
    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: icmp
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
discovery_relays:
  - id: "relay-main"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    ports: [51821]
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

    const codec = ClientProfileCodec();

    expect(
      () => codec.parseCurrentContractRaw(raw),
      throwsA(isA<ClientProfileContractException>()),
    );
  });

  test('accepts current admin key with omitted optional defaults', () {
    const raw = '''
discovery_relays:
    - id: relay-37
      addr: abobusserver.zapto.org
      short_id: 2
      relay_key: 96e301c6efa7fc72292f0e7246458e7a9ab15c5520487c6cdced982a643ea312
      transport_ports:
        bt-utp:
          - 51821
          - 51822
        ws:
          - 51823
        https-rest:
          - 443
        bt-tcp:
          - 51824
transport:
    mode: auto
server_failback_delay_sec: 60
user_id: 2
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
servers:
    - id: germany-2
      key: 34d84bfe5e859dcb075eb96670c3667863305940707e7a6dab22fcb38c08ae72
      priority: 1
split_tunnel:
    enabled: false
    apps_mode: whitelist
    apps_win: []
    apps_android: []
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseCurrentContractRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.userId, '2');
    expect(profile.relays.single.relayKey, startsWith('96e301c6'));
    expect(profile.packetFragmentPayloadBytes, 0);
    expect(profile.disablePacketBatching, isFalse);
    expect(profile.windowsApps, isEmpty);
    expect(encoded, contains('network_rescue:'));
    expect(encoded, contains('profile: \'off\''));
    expect(encoded, contains('packet_fragment_payload_bytes: 0'));
    expect(encoded, contains('disable_packet_batching: false'));
    expect(encoded, contains('apps_win: []'));
    expect(encoded, contains('apps_android: []'));
  });

  test('accepts current disabled split tunnel without empty app lists', () {
    const raw = '''
discovery_relays:
    - id: relay-37
      addr: abobusserver.zapto.org
      short_id: 2
      transport_ports:
        bt-tcp:
            - 52031
            - 52032
            - 52033
            - 52034
            - 52035
            - 52036
        bt-utp:
            - 52021
            - 52022
            - 52023
            - 52024
            - 52025
        https-rest:
            - 443
        raw-udp:
            - 52038
        ws:
            - 52026
            - 52027
            - 52028
            - 52029
            - 52030
      relay_key: 96e301c6efa7fc72292f0e7246458e7a9ab15c5520487c6cdced982a643ea312
transport:
    mode: auto
probe:
    health_bytes: 65536
    health_timeout_ms: 3000
    health_concurrency: 3
    speed_quick_bytes: 65536
    speed_bytes: 67108864
    speed_timeout_ms: 10000
network_rescue:
    profile: "off"
server_failback_delay_sec: 60
user_id: 4
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
servers:
    - id: germany-2
      key: e8fc7a3d038e1470442372c283b4a4dbeddf5f5750029a3d8e15df2796d2d273
      priority: 1
split_tunnel:
    enabled: false
    apps_mode: whitelist
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseCurrentContractRaw(raw);
    final imported = ClientController(
      codec: codec,
    ).importProfileFromKey('mayday://import/${base64Encode(utf8.encode(raw))}');
    final encoded = codec.encodeYaml(profile);

    expect(profile.userId, '4');
    expect(imported.profile.userId, '4');
    expect(imported.filePath, 'mayday://import');
    expect(profile.windowsApps, isEmpty);
    expect(profile.androidApps, isEmpty);
    expect(profile.relays.single.transportPorts['raw-udp'], [52038]);
    expect(encoded, contains('probe:'));
    expect(encoded, contains('raw-udp: [52038]'));
    expect(encoded, contains('network_rescue:'));
    expect(encoded, contains('enabled: false'));
    expect(encoded, contains("profile: 'off'"));
    expect(encoded, contains('apps_win: []'));
    expect(encoded, contains('apps_android: []'));
  });

  test('imports split tunnel Windows apps', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821]
      ws: [51822]
      https-rest: [443]
      bt-tcp: [51823]
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: true
  apps_mode: whitelist
  apps_win: ["C:/Apps/App.exe"]
  apps_android: []
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.windowsApps, ['C:/Apps/App.exe']);
    expect(encoded, contains('apps_win: [\'C:/Apps/App.exe\']'));
    expect(encoded, isNot(contains('\n  apps:')));
  });

  test('missing metrics config keeps file metrics disabled by default', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821]
      ws: [51822]
      https-rest: [443]
      bt-tcp: [51823]
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: false
  apps_mode: whitelist
  apps_win: []
  apps_android: []
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.metrics.enabled, isTrue);
    expect(profile.metrics.fileEnabled, isFalse);
    expect(profile.metrics.fileDir, isEmpty);
    expect(encoded, isNot(contains('metrics:')));
  });

  test(
      'app settings default autostart on and preserve it across language saves',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-settings-');
    addTearDown(() => tempDir.delete(recursive: true));

    final settings = AppLanguageSettings(
      runtimePathsService: _FakeRuntimePathsService(tempDir.path),
    );

    expect(await settings.loadAutoStartEnabled(), isTrue);

    await settings.saveAutoStartEnabled(false);
    await settings.save(AppLanguage.english);

    expect(await settings.load(), AppLanguage.english);
    expect(await settings.loadAutoStartEnabled(), isFalse);
  });

  test('profile storage encrypts saved config at rest', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-profile-');
    addTearDown(() => tempDir.delete(recursive: true));

    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821]
      ws: [51822]
      https-rest: [443]
      bt-tcp: [51823]
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: false
  apps_mode: whitelist
  apps_win: []
  apps_android: []
''';

    const codec = ClientProfileCodec();
    final storage = ClientProfileStorage(
      runtimePathsService: _FakeRuntimePathsService(tempDir.path),
      codec: codec,
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
      encryptionService: const _FakeProfileEncryptionService(),
    );

    final savedFile = await storage.saveProfile(codec.parseRaw(raw));
    final encrypted = await savedFile.readAsString();
    final legacyPlainFile = File(p.join(tempDir.path, 'config', 'client.yaml'));
    final loaded = await storage.loadSavedProfile();

    expect(savedFile.path, endsWith('client.yaml.dpapi'));
    expect(await legacyPlainFile.exists(), isFalse);
    expect(encrypted, isNot(contains('relay.example.net')));
    expect(loaded?.relays.single.addr, 'relay.example.net');
  });

  test('profile storage rejects saved legacy core contract', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-profile-');
    addTearDown(() => tempDir.delete(recursive: true));

    const raw = '''
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
''';
    const encryptionService = _FakeProfileEncryptionService();
    final runtimePathsService = _FakeRuntimePathsService(tempDir.path);
    final paths = await runtimePathsService.getPaths();
    await Directory(paths.configDir).create(recursive: true);
    await File(paths.configPath).writeAsString(
      await encryptionService.encrypt(raw),
    );

    final storage = ClientProfileStorage(
      runtimePathsService: runtimePathsService,
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
      encryptionService: encryptionService,
    );

    expect(
      storage.loadSavedProfileForCurrentContract,
      throwsA(isA<ClientProfileContractException>()),
    );
  });

  test('profile storage accepts current contract and writes metadata',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-profile-');
    addTearDown(() => tempDir.delete(recursive: true));

    const raw = '''
user_id: 1
server_failback_delay_sec: 60
transport:
  mode: auto
prestart_full_probe: false
steady_state_quick_probe_enabled: false
steady_state_benchmark_enabled: false
disable_ipv6: false
tunnel_mtu: 1280
packet_fragment_payload_bytes: 0
disable_packet_batching: false
discovery_relays:
  - id: "relay-abobus"
    addr: "relay.example.net"
    short_id: 1
    relay_key: "$userKey"
    transport_ports:
      bt-utp: [51821]
      ws: [51822]
      https-rest: [443]
      bt-tcp: [51823]
servers:
  - id: "netherlands-1"
    key: "$userKey"
    priority: 1
split_tunnel:
  enabled: false
  apps_mode: whitelist
  apps_win: []
  apps_android: []
''';
    const encryptionService = _FakeProfileEncryptionService();
    final runtimePathsService = _FakeRuntimePathsService(tempDir.path);
    final paths = await runtimePathsService.getPaths();
    await Directory(paths.configDir).create(recursive: true);
    await File(paths.configPath).writeAsString(
      await encryptionService.encrypt(raw),
    );

    final storage = ClientProfileStorage(
      runtimePathsService: runtimePathsService,
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
      encryptionService: encryptionService,
    );

    final loaded = await storage.loadSavedProfileForCurrentContract();
    final metadataFile = File(
      p.join(paths.configDir, 'client_profile_metadata.json'),
    );
    final metadata = jsonDecode(await metadataFile.readAsString());

    expect(loaded?.relays.single.id, 'relay-abobus');
    expect(metadata['contractVersion'], 5);
  });

  test('profile encryption service round-trips without plaintext output',
      () async {
    const secret = 'relay_addr=1.2.3.4:51821';
    const service = ProfileEncryptionService();

    final encrypted = await service.encrypt(secret);
    final decrypted = await service.decrypt(encrypted);

    expect(encrypted, isNot(contains('1.2.3.4')));
    expect(decrypted, secret);
  });
}

class _FakeProfileEncryptionService extends ProfileEncryptionService {
  const _FakeProfileEncryptionService();

  @override
  Future<String> encrypt(String plainText) async {
    return 'fake:${base64Encode(utf8.encode(plainText))}';
  }

  @override
  Future<String> decrypt(String encryptedText) async {
    final payload = encryptedText.startsWith('fake:')
        ? encryptedText.substring('fake:'.length)
        : encryptedText;
    return utf8.decode(base64Decode(payload));
  }
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

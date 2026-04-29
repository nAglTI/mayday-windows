import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('imports and exports canonical config without dropping fields', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
server_failback_delay_sec: 60
future_top: "kept"

transport:
  mode: tcp
  future_transport: true

metrics:
  enabled: true
  window_seconds: 600
  file_enabled: true
  file_dir: "./metrics"
  future_metrics: "kept"

relays:
  - id: "relay-abobus"
    addr: "1.2.3.4:51821"
    short_id: 1
    ports: [51821, 51822, 51823, 51824]
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

    expect(profile.relays.single.ports, [51821, 51822, 51823, 51824]);
    expect(profile.metrics.fileDir, './metrics');
    expect(encoded, contains('ports: [51821, 51822, 51823, 51824]'));
    expect(encoded, contains('metrics:'));
    expect(encoded, contains('server_failback_delay_sec: 60'));
    expect(encoded, contains('split_tunnel:'));
    expect(encoded, contains('future_top: \'kept\''));
    expect(encoded, contains('future_transport: true'));
    expect(encoded, contains('future_metrics: \'kept\''));
    expect(encoded, contains('future_relay: \'kept\''));
    expect(encoded, contains('future_server: \'kept\''));
    expect(encoded, contains('future_split: \'kept\''));
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
metrics:
  enabled: true
  window_seconds: 600
  file_enabled: true
  file_dir: "./metrics"
  future_metrics: "kept"
relays:
  - id: "relay-abobus"
    addr: "1.2.3.4:51821"
    short_id: 1
    ports: [51821, 51822]
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
    expect(encoded, contains('future_metrics: \'kept\''));
    expect(encoded, contains('future_relay: \'kept\''));
    expect(encoded, contains('future_server: \'kept\''));
    expect(encoded, contains('future_split: \'kept\''));
  });

  test('imports legacy split tunnel apps as Windows apps', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
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
  enabled: true
  mode: whitelist
  apps: ["C:/Legacy/App.exe"]
''';

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.windowsApps, ['C:/Legacy/App.exe']);
    expect(encoded, contains('apps_win: [\'C:/Legacy/App.exe\']'));
    expect(encoded, isNot(contains('\n  apps:')));
  });

  test('missing metrics config keeps file metrics disabled by default', () {
    const raw = '''
user_id: 1
tun_name: "VPN0"
dns: "1.1.1.1"
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

    const codec = ClientProfileCodec();
    final profile = codec.parseRaw(raw);
    final encoded = codec.encodeYaml(profile);

    expect(profile.metrics.enabled, isTrue);
    expect(profile.metrics.fileEnabled, isFalse);
    expect(profile.metrics.fileDir, isEmpty);
    expect(encoded, contains('file_enabled: false'));
    expect(encoded, contains('file_dir: \'\''));
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
    expect(encrypted, isNot(contains('1.2.3.4')));
    expect(loaded?.relays.single.addr, '1.2.3.4:51821');
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
      clientExePath: p.join(root, 'runtime', 'vpnclient.exe'),
      mutableRoot: root,
      configDir: configDir,
      configPath: p.join(configDir, 'client.yaml.dpapi'),
    );
  }
}

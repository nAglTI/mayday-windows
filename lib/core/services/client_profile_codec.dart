import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../l10n/app_texts.dart';
import '../models/client_profile.dart';
import '../models/metrics_config.dart';
import '../models/network_rescue_config.dart';
import '../models/relay_target.dart';
import '../models/server_target.dart';
import '../models/split_tunnel_mode.dart';
import '../models/transport_config.dart';

class ClientProfileContractException implements Exception {
  const ClientProfileContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ClientProfileCodec {
  const ClientProfileCodec({AppTextCatalog? appTextCatalog})
      : _textCatalog =
            appTextCatalog ?? const AppTextCatalog(AppLanguage.english);

  static const _defaultTunName = 'VPN0';
  static const _defaultDns = '1.1.1.1';
  static final _plainYamlKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$');
  static final _serverKeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  static const _topLevelKeys = {
    'user_id',
    'tun_name',
    'dns',
    'server_failback_delay_sec',
    'prestart_full_probe',
    'steady_state_quick_probe_enabled',
    'steady_state_benchmark_enabled',
    'disable_ipv6',
    'tunnel_mtu',
    'packet_fragment_payload_bytes',
    'disable_packet_batching',
    'discovery_relays',
    'transport',
    'network_rescue',
    'metrics',
    'relays',
    'servers',
    'split_tunnel',
  };
  static const _transportKeys = {'mode'};
  static const _networkRescueKeys = {'enabled', 'profile'};
  static const _metricsKeys = {
    'enabled',
    'window_seconds',
    'file_enabled',
    'file_dir',
  };
  static const _relayKeys = {
    'id',
    'addr',
    'short_id',
    'relay_key',
    'ports',
    'transport_ports',
  };
  static const _serverKeys = {
    'id',
    'key',
    'priority',
  };
  static const _splitTunnelKeys = {
    'enabled',
    'mode',
    'apps_mode',
    'apps',
    'apps_win',
    'apps_android',
  };

  final AppTextCatalog _textCatalog;

  ClientProfile parseRaw(String rawConfig) {
    return _profileFromMap(_configMapFromRaw(rawConfig));
  }

  ClientProfile parseCurrentContractRaw(String rawConfig) {
    final config = _configMapFromRaw(rawConfig);
    _validateCurrentContract(config);
    return _profileFromMap(config);
  }

  void validateCurrentContractRaw(String rawConfig) {
    final config = _configMapFromRaw(rawConfig);
    _validateCurrentContract(config);
    _profileFromMap(config);
  }

  Map<String, Object?> _configMapFromRaw(String rawConfig) {
    final trimmed = rawConfig.trim();
    if (trimmed.isEmpty) {
      throw FormatException(_textCatalog.t('codec.empty'));
    }

    final plainConfig = trimmed.startsWith('{') || trimmed.startsWith('[')
        ? _plainValue(jsonDecode(trimmed))
        : _plainValue(loadYaml(trimmed));

    if (plainConfig is! Map<String, Object?>) {
      throw FormatException(_textCatalog.t('codec.unsupported_yaml'));
    }

    return plainConfig;
  }

  String encodeYaml(ClientProfile profile) {
    _validateProfile(profile);

    final userId = int.parse(profile.userId.trim());
    final root = <String, Object?>{
      'user_id': userId,
      'server_failback_delay_sec': profile.serverFailbackDelaySec,
      'transport': _encodeTransport(profile.transport),
      'network_rescue': _encodeNetworkRescue(profile.networkRescue),
      'prestart_full_probe': profile.prestartFullProbe,
      'steady_state_quick_probe_enabled': profile.steadyStateQuickProbeEnabled,
      'steady_state_benchmark_enabled': profile.steadyStateBenchmarkEnabled,
      'disable_ipv6': profile.disableIpv6,
      'tunnel_mtu': profile.tunnelMtu,
      'packet_fragment_payload_bytes': profile.packetFragmentPayloadBytes,
      'disable_packet_batching': profile.disablePacketBatching,
      'discovery_relays': _encodeRelays(profile.relays),
      'servers': _encodeServers(profile.servers),
      if (_shouldEncodeMetrics(profile.metrics))
        'metrics': _encodeMetrics(profile.metrics),
      'split_tunnel': _encodeSplitTunnel(profile),
    };

    root.addAll(_unknownFields(profile.extraFields, _topLevelKeys));
    return _writeYaml(root).trimRight();
  }

  void _validateProfile(ClientProfile profile) {
    final userId = int.tryParse(profile.userId.trim());
    if (userId == null) {
      throw FormatException(_textCatalog.t('codec.user_id_integer'));
    }
    if (userId < 1) {
      throw FormatException(_textCatalog.t('codec.user_id_positive'));
    }

    if (profile.serverFailbackDelaySec < -1) {
      throw FormatException(_textCatalog.t('codec.failback_delay_invalid'));
    }

    if (profile.metrics.windowSeconds < 1) {
      throw FormatException(_textCatalog.t('codec.metrics_window_invalid'));
    }
    if (!_validTunnelMtu(profile.tunnelMtu, disableIpv6: profile.disableIpv6)) {
      throw FormatException(_textCatalog.t('codec.tunnel_mtu_invalid'));
    }
    if (!_validPacketFragmentPayload(profile.packetFragmentPayloadBytes)) {
      throw FormatException(
        _textCatalog.t('codec.packet_fragment_payload_invalid'),
      );
    }
    if (profile.relays.isEmpty) {
      throw FormatException(_textCatalog.t('codec.relay_required'));
    }

    final relayShortIds = <int>{};
    for (final relay in profile.relays) {
      if (relay.addr.trim().isEmpty) {
        throw FormatException(_textCatalog.t('codec.relay_addr_required'));
      }
      if (relay.shortId < 1 || relay.shortId > 65535) {
        throw FormatException(_textCatalog.t('codec.relay_short_id_invalid'));
      }
      if (!relayShortIds.add(relay.shortId)) {
        throw FormatException(_textCatalog.t('codec.relay_short_id_unique'));
      }
      if (!_serverKeyPattern.hasMatch(relay.relayKey.trim())) {
        throw FormatException(_textCatalog.t('codec.relay_key_hex'));
      }

      final transportPorts = _encodeTransportPorts(relay.transportPorts);
      final ports = _normalizeIntList(
        transportPorts.values.expand((ports) => ports),
      );
      if (ports.isEmpty) {
        throw FormatException(_textCatalog.t('codec.relay_ports_required'));
      }
      if (ports.any((port) => port < 1 || port > 65535)) {
        throw FormatException(_textCatalog.t('codec.relay_ports_invalid'));
      }
    }

    if (profile.servers.isEmpty) {
      throw FormatException(_textCatalog.t('codec.server_required'));
    }

    for (final server in profile.servers) {
      if (server.id.trim().isEmpty) {
        throw FormatException(_textCatalog.t('codec.server_id_required'));
      }
      final key = server.key.trim();
      if (key.isEmpty) {
        throw FormatException(_textCatalog.t('codec.server_key_required'));
      }
      if (!_serverKeyPattern.hasMatch(key)) {
        throw FormatException(_textCatalog.t('codec.server_key_hex'));
      }
      if (server.priority < 1) {
        throw FormatException(_textCatalog.t('codec.server_priority_invalid'));
      }
    }

    if (profile.splitTunnelMode != SplitTunnelMode.disabled &&
        _normalizeStringList(profile.windowsApps).isEmpty) {
      throw FormatException(_textCatalog.t('codec.split_apps_required'));
    }
  }

  void _validateCurrentContract(Map<String, Object?> map) {
    if (!map.containsKey('discovery_relays')) {
      if (map.containsKey('relays')) {
        throw ClientProfileContractException(
          _textCatalog.t('codec.contract_legacy_relays'),
        );
      }
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_discovery_relays_required'),
      );
    }

    if (!map.containsKey('servers')) {
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_servers_required'),
      );
    }

    final splitTunnel = _toMap(map['split_tunnel']);
    if (!map.containsKey('split_tunnel') ||
        !splitTunnel.containsKey('apps_mode')) {
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_apps_mode_required'),
      );
    }
    final splitTunnelEnabled = _readBool(splitTunnel['enabled']);
    if (splitTunnelEnabled && !splitTunnel.containsKey('apps_win')) {
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_apps_win_required'),
      );
    }
    if (splitTunnelEnabled && !splitTunnel.containsKey('apps_android')) {
      throw ClientProfileContractException(
        _textCatalog.t(
          'codec.contract_current_field_required',
          {'field': 'split_tunnel.apps_android'},
        ),
      );
    }

    final transport = _toMap(map['transport']);
    if (!TransportMode.supportsWireValue(transport['mode']?.toString())) {
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_transport_mode_unsupported'),
      );
    }

    final networkRescue = _toMap(map['network_rescue']);
    if (map.containsKey('network_rescue') &&
        !NetworkRescueProfile.supportsWireValue(
          networkRescue['profile']?.toString(),
        )) {
      throw ClientProfileContractException(
        _textCatalog.t('codec.contract_network_rescue_profile_unsupported'),
      );
    }

    final rawRelays = map['discovery_relays'];
    if (rawRelays is Iterable) {
      for (final item in rawRelays) {
        final relay = _toMap(item);
        final relayKey = relay['relay_key']?.toString().trim() ?? '';
        if (!_serverKeyPattern.hasMatch(relayKey)) {
          throw ClientProfileContractException(
            _textCatalog.t('codec.contract_relay_key_required'),
          );
        }
        final transportPorts = _readTransportPorts(relay['transport_ports']);
        if (relay.containsKey('ports') || transportPorts.isEmpty) {
          throw ClientProfileContractException(
            _textCatalog.t('codec.contract_transport_ports_required'),
          );
        }
      }
    }
  }

  ClientProfile _profileFromMap(Map<String, Object?> map) {
    final userId = map['user_id']?.toString().trim() ?? '';
    if (userId.isEmpty) {
      throw FormatException(_textCatalog.t('codec.user_id_required'));
    }

    final splitTunnel = _toMap(map['split_tunnel']);
    final splitEnabled = _readBool(splitTunnel['enabled']);
    final splitMode = SplitTunnelMode.fromWireValue(
      (splitTunnel['apps_mode'] ?? splitTunnel['mode'])?.toString(),
      enabled: splitEnabled,
    );

    final profile = ClientProfile(
      relays: _parseDiscoveryRelays(map),
      userId: userId,
      servers: _parseServers(map['servers']),
      tunName: _cleanOrDefault(
        map['tun_name']?.toString() ?? '',
        _defaultTunName,
      ),
      dnsServers: _parseDns(map['dns']),
      transport: _parseTransport(map['transport']),
      networkRescue: _parseNetworkRescue(map['network_rescue']),
      metrics: _parseMetrics(map['metrics']),
      serverFailbackDelaySec: _parseInt(map['server_failback_delay_sec']) ?? 60,
      prestartFullProbe: _readBool(map['prestart_full_probe']),
      steadyStateQuickProbeEnabled:
          _readBool(map['steady_state_quick_probe_enabled']),
      steadyStateBenchmarkEnabled:
          _readBool(map['steady_state_benchmark_enabled']),
      disableIpv6: _readBool(map['disable_ipv6']),
      tunnelMtu: _parseInt(map['tunnel_mtu']) ?? 1280,
      packetFragmentPayloadBytes:
          _parseInt(map['packet_fragment_payload_bytes']) ?? 0,
      disablePacketBatching: _readBool(map['disable_packet_batching']),
      splitTunnelMode: splitMode,
      windowsApps: _windowsAppsFromSplitTunnel(splitTunnel),
      androidApps: _readStringList(splitTunnel['apps_android']),
      splitTunnelExtraFields: _unknownFields(
        splitTunnel,
        _splitTunnelKeys,
      ),
      extraFields: _unknownFields(map, _topLevelKeys),
    );

    _validateProfile(profile);
    return profile;
  }

  TransportConfig _parseTransport(dynamic rawTransport) {
    final transport = _toMap(rawTransport);
    return TransportConfig(
      mode: TransportMode.fromWireValue(transport['mode']?.toString()),
      extraFields: _unknownFields(transport, _transportKeys),
    );
  }

  NetworkRescueConfig _parseNetworkRescue(dynamic rawNetworkRescue) {
    final networkRescue = _toMap(rawNetworkRescue);
    final explicitProfile = networkRescue['profile']?.toString();
    final enabled = _readBool(networkRescue['enabled']);
    final profile = explicitProfile == null && enabled
        ? NetworkRescueProfile.stable
        : NetworkRescueProfile.fromWireValue(explicitProfile);
    return NetworkRescueConfig(
      profile: profile,
      extraFields: _unknownFields(networkRescue, _networkRescueKeys),
    );
  }

  MetricsConfig _parseMetrics(dynamic rawMetrics) {
    final metrics = _toMap(rawMetrics);
    return MetricsConfig(
      enabled: _readBool(metrics['enabled'], fallback: true),
      windowSeconds: _parseInt(metrics['window_seconds']) ?? 600,
      fileEnabled: _readBool(metrics['file_enabled']),
      fileDir: metrics['file_dir']?.toString().trim() ?? '',
      extraFields: _unknownFields(metrics, _metricsKeys),
    );
  }

  List<RelayTarget> _parseDiscoveryRelays(Map<String, Object?> map) {
    final rawRelays = map['discovery_relays'];
    if (rawRelays is! Iterable) {
      return const [];
    }

    final relays = <RelayTarget>[];
    for (var index = 0; index < rawRelays.length; index += 1) {
      final relayMap = _toMap(rawRelays.elementAt(index));
      relays.add(
        RelayTarget(
          id: _cleanOrDefault(
            relayMap['id']?.toString() ?? '',
            'relay-${index + 1}',
          ),
          addr: relayMap['addr']?.toString().trim() ?? '',
          shortId: _parseInt(relayMap['short_id']) ?? index + 1,
          relayKey: relayMap['relay_key']?.toString().trim() ?? '',
          transportPorts: _readTransportPorts(relayMap['transport_ports']),
          extraFields: _unknownFields(relayMap, _relayKeys),
        ),
      );
    }
    return relays;
  }

  List<ServerTarget> _parseServers(dynamic rawServers) {
    if (rawServers is! Iterable) {
      return const [];
    }

    final servers = <ServerTarget>[];
    for (final item in rawServers) {
      final serverMap = _toMap(item);
      servers.add(
        ServerTarget(
          id: serverMap['id']?.toString().trim() ?? '',
          key: serverMap['key']?.toString().trim() ?? '',
          priority: _parseInt(serverMap['priority']) ?? 1,
          extraFields: _unknownFields(serverMap, _serverKeys),
        ),
      );
    }
    return servers;
  }

  List<String> _parseDns(dynamic rawDns) {
    if (rawDns is Iterable) {
      final values = _normalizeStringList(rawDns.map((item) => '$item'));
      return values.isEmpty ? const [_defaultDns] : values;
    }

    final value = rawDns?.toString() ?? '';
    final parsed = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return parsed.isEmpty ? const [_defaultDns] : parsed;
  }

  Map<String, Object?> _encodeTransport(TransportConfig transport) {
    return {
      'mode': transport.mode.wireValue,
      ..._unknownFields(transport.extraFields, _transportKeys),
    };
  }

  Map<String, Object?> _encodeNetworkRescue(
    NetworkRescueConfig networkRescue,
  ) {
    return {
      'enabled': networkRescue.enabled,
      'profile': networkRescue.profile.wireValue,
      ..._unknownFields(networkRescue.extraFields, _networkRescueKeys),
    };
  }

  Map<String, Object?> _encodeMetrics(MetricsConfig metrics) {
    return {
      'enabled': metrics.enabled,
      'window_seconds': metrics.windowSeconds,
      'file_enabled': metrics.fileEnabled,
      'file_dir': metrics.fileDir.trim(),
      ..._unknownFields(metrics.extraFields, _metricsKeys),
    };
  }

  bool _shouldEncodeMetrics(MetricsConfig metrics) {
    return metrics.enabled != true ||
        metrics.windowSeconds != 600 ||
        metrics.fileEnabled != false ||
        metrics.fileDir.trim().isNotEmpty ||
        metrics.extraFields.isNotEmpty;
  }

  List<Map<String, Object?>> _encodeRelays(List<RelayTarget> relays) {
    return [
      for (var index = 0; index < relays.length; index += 1)
        {
          'id': _cleanOrDefault(relays[index].id, 'relay-${index + 1}'),
          'addr': relays[index].addr.trim(),
          'short_id': relays[index].shortId,
          'relay_key': relays[index].relayKey.trim(),
          'transport_ports': _encodeTransportPorts(
            relays[index].transportPorts,
          ),
          ..._unknownFields(relays[index].extraFields, _relayKeys),
        },
    ];
  }

  List<Map<String, Object?>> _encodeServers(List<ServerTarget> servers) {
    return [
      for (final server in servers)
        {
          'id': server.id.trim(),
          'key': server.key.trim(),
          'priority': server.priority,
          ..._unknownFields(server.extraFields, _serverKeys),
        },
    ];
  }

  Map<String, Object?> _encodeSplitTunnel(ClientProfile profile) {
    return {
      'enabled': profile.splitTunnelMode != SplitTunnelMode.disabled,
      'apps_mode': profile.splitTunnelMode.wireValue ?? 'whitelist',
      'apps_win': _normalizeStringList(profile.windowsApps),
      'apps_android': _normalizeStringList(profile.androidApps),
      ..._unknownFields(profile.splitTunnelExtraFields, _splitTunnelKeys),
    };
  }

  List<String> _windowsAppsFromSplitTunnel(Map<String, Object?> splitTunnel) {
    final appsWin = _readStringList(splitTunnel['apps_win']);
    if (appsWin.isNotEmpty) {
      return appsWin;
    }
    return _readStringList(splitTunnel['apps']);
  }

  Map<String, List<int>> _readTransportPorts(dynamic rawValue) {
    final map = _toMap(rawValue);
    if (map.isEmpty) {
      return const {};
    }

    final result = <String, List<int>>{};
    for (final entry in map.entries) {
      final protocol = entry.key.trim();
      final ports = _readIntList(entry.value);
      if (protocol.isEmpty || ports.isEmpty) {
        continue;
      }
      result[protocol] = ports;
    }
    return result;
  }

  Map<String, List<int>> _encodeTransportPorts(
    Map<String, List<int>> transportPorts,
  ) {
    return {
      for (final entry in transportPorts.entries)
        if (entry.key.trim().isNotEmpty &&
            _normalizeIntList(entry.value).isNotEmpty)
          entry.key.trim(): _normalizeIntList(entry.value),
    };
  }

  List<String> _readStringList(dynamic rawValue) {
    if (rawValue is! Iterable) {
      return const [];
    }

    return _normalizeStringList(rawValue.map((item) => item.toString()));
  }

  List<int> _readIntList(dynamic rawValue) {
    if (rawValue is! Iterable) {
      return const [];
    }

    return _normalizeIntList(rawValue.map((item) {
      if (item is int) {
        return item;
      }
      return int.tryParse(item.toString().trim());
    }).whereType<int>());
  }

  List<int> _normalizeIntList(Iterable<int> values) {
    final seen = <int>{};
    final result = <int>[];
    for (final value in values) {
      if (!seen.add(value)) {
        continue;
      }
      result.add(value);
    }
    return result;
  }

  bool _readBool(dynamic rawValue, {bool fallback = false}) {
    if (rawValue == null) {
      return fallback;
    }
    if (rawValue is bool) {
      return rawValue;
    }

    final normalized = rawValue.toString().trim().toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => fallback,
    };
  }

  int? _parseInt(dynamic rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    return int.tryParse(rawValue?.toString().trim() ?? '');
  }

  bool _validTunnelMtu(int value, {required bool disableIpv6}) {
    final min = disableIpv6 ? 100 : 1280;
    return value >= min && value <= 1500;
  }

  bool _validPacketFragmentPayload(int value) {
    return value == 0 || (value >= 64 && value <= 65536);
  }

  Map<String, Object?> _toMap(dynamic rawValue) {
    final plain = _plainValue(rawValue);
    if (plain is Map<String, Object?>) {
      return plain;
    }
    return const {};
  }

  Object? _plainValue(dynamic value) {
    if (value is YamlMap || value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _plainValue(entry.value),
      };
    }
    if (value is YamlList || value is List) {
      return [for (final item in value) _plainValue(item)];
    }
    return value;
  }

  Map<String, Object?> _unknownFields(
    Map<String, Object?> fields,
    Set<String> knownKeys,
  ) {
    return {
      for (final entry in fields.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  List<String> _normalizeStringList(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      result.add(trimmed);
    }
    return result;
  }

  String _cleanOrDefault(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _writeYaml(Map<String, Object?> map) {
    final buffer = StringBuffer();
    _writeYamlMap(buffer, map, 0);
    return buffer.toString();
  }

  void _writeYamlMap(
    StringBuffer buffer,
    Map<String, Object?> map,
    int indent,
  ) {
    for (final entry in map.entries) {
      _writeYamlEntry(buffer, entry.key, entry.value, indent);
    }
  }

  void _writeYamlEntry(
    StringBuffer buffer,
    String key,
    Object? value,
    int indent,
  ) {
    final prefix = ' ' * indent;
    final encodedKey = _yamlKey(key);
    if (_isScalar(value)) {
      buffer.writeln('$prefix$encodedKey: ${_yamlScalar(value)}');
      return;
    }

    if (value is Iterable) {
      final items = value.toList();
      if (items.isEmpty) {
        buffer.writeln('$prefix$encodedKey: []');
      } else if (items.every(_isScalar)) {
        buffer.writeln('$prefix$encodedKey: ${_inlineList(items)}');
      } else {
        buffer.writeln('$prefix$encodedKey:');
        _writeYamlList(buffer, items, indent + 2);
      }
      return;
    }

    final map = _toMap(value);
    if (map.isEmpty) {
      buffer.writeln('$prefix$encodedKey: {}');
      return;
    }

    buffer.writeln('$prefix$encodedKey:');
    _writeYamlMap(buffer, map, indent + 2);
  }

  void _writeYamlList(
    StringBuffer buffer,
    List<Object?> items,
    int indent,
  ) {
    final prefix = ' ' * indent;
    for (final item in items) {
      if (_isScalar(item)) {
        buffer.writeln('$prefix- ${_yamlScalar(item)}');
        continue;
      }

      if (item is Iterable) {
        final items = item.toList();
        if (items.isEmpty) {
          buffer.writeln('$prefix- []');
        } else {
          buffer.writeln('$prefix-');
          _writeYamlList(buffer, items, indent + 2);
        }
        continue;
      }

      final map = _toMap(item);
      if (map.isEmpty) {
        buffer.writeln('$prefix- {}');
        continue;
      }

      final entries = map.entries.toList();
      final first = entries.first;
      if (_isScalar(first.value)) {
        buffer.writeln(
          '$prefix- ${_yamlKey(first.key)}: ${_yamlScalar(first.value)}',
        );
      } else {
        buffer.writeln('$prefix- ${_yamlKey(first.key)}:');
        _writeYamlComplexValue(buffer, first.value, indent + 4);
      }

      for (final entry in entries.skip(1)) {
        _writeYamlEntry(buffer, entry.key, entry.value, indent + 2);
      }
    }
  }

  void _writeYamlComplexValue(
    StringBuffer buffer,
    Object? value,
    int indent,
  ) {
    if (value is Iterable) {
      _writeYamlList(buffer, value.toList(), indent);
      return;
    }
    _writeYamlMap(buffer, _toMap(value), indent);
  }

  bool _isScalar(Object? value) {
    return value == null || value is String || value is num || value is bool;
  }

  String _inlineList(List<Object?> values) {
    return '[${values.map(_yamlScalar).join(', ')}]';
  }

  String _yamlScalar(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is bool || value is num) {
      return '$value';
    }
    return _yamlString(value.toString());
  }

  String _yamlKey(String key) {
    return _plainYamlKey.hasMatch(key) ? key : _yamlString(key);
  }

  String _yamlString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }
}

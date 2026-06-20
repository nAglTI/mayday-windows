import 'dart:convert';

class RuntimeStatusSnapshot {
  const RuntimeStatusSnapshot({
    this.coreState = '',
    this.vpnState = '',
    this.activeRelayId = '',
    this.activeTransportId = '',
    this.activeServerId = '',
    this.uploadBps = 0,
    this.downloadBps = 0,
    this.aggregateBps = 0,
    this.protocolDiagnostics = const [],
    this.endpointDiagnostics = const [],
  });

  static const empty = RuntimeStatusSnapshot();

  final String coreState;
  final String vpnState;
  final String activeRelayId;
  final String activeTransportId;
  final String activeServerId;
  final double uploadBps;
  final double downloadBps;
  final double aggregateBps;
  final List<String> protocolDiagnostics;
  final List<String> endpointDiagnostics;

  bool get hasActiveRoute =>
      activeRelayId.isNotEmpty ||
      activeTransportId.isNotEmpty ||
      activeServerId.isNotEmpty;

  bool get hasRates => uploadBps > 0 || downloadBps > 0 || aggregateBps > 0;

  bool get hasData =>
      coreState.isNotEmpty ||
      vpnState.isNotEmpty ||
      hasActiveRoute ||
      hasRates ||
      protocolDiagnostics.isNotEmpty ||
      endpointDiagnostics.isNotEmpty;

  static RuntimeStatusSnapshot? tryParse(String rawStatus) {
    final trimmed = rawStatus.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(_jsonPayload(trimmed));
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return fromJson(decoded);
    } catch (_) {
      return _tryParseLineStatus(trimmed);
    }
  }

  static RuntimeStatusSnapshot fromJson(Map<String, Object?> json) {
    final protocols = _listOfMaps(json['protocols']);
    final endpoints = _listOfMaps(json['endpoints']);
    final activeTransportId = _firstString(json, const [
      'active_transport',
      'active_protocol',
      'active_transport_id',
      'transport',
    ]);
    final uploadBps = _firstPositiveDouble(json, _uploadRateFields);
    final downloadBps = _firstPositiveDouble(json, _downloadRateFields);
    final aggregateBps = _firstPositiveDouble(json, _aggregateRateFields);
    final fallbackUploadBps = uploadBps > 0
        ? uploadBps
        : _maxDouble(
            _maxFirstPositiveDouble(protocols, _uploadRateFields),
            _maxFirstPositiveDouble(endpoints, _uploadRateFields),
          );
    final fallbackDownloadBps = downloadBps > 0
        ? downloadBps
        : _maxDouble(
            _maxFirstPositiveDouble(protocols, _downloadRateFields),
            _maxFirstPositiveDouble(endpoints, _downloadRateFields),
          );
    final fallbackAggregateBps = aggregateBps > 0
        ? aggregateBps
        : [
            fallbackUploadBps + fallbackDownloadBps,
            _maxFirstPositiveDouble(protocols, _aggregateRateFields),
            _maxFirstPositiveDouble(endpoints, _aggregateRateFields),
          ].reduce(_maxDouble);

    return RuntimeStatusSnapshot(
      coreState: _stringValue(json['state']),
      vpnState: _firstString(json, const ['vpn_state', 'vpn']),
      activeRelayId: _firstString(json, const [
        'active_relay_id',
        'active_relay',
        'relay',
      ]),
      activeTransportId: activeTransportId,
      activeServerId: _firstString(json, const [
        'active_server_id',
        'active_exit_id',
        'active_exit',
        'exit',
        'server',
      ]),
      uploadBps: fallbackUploadBps,
      downloadBps: fallbackDownloadBps,
      aggregateBps: fallbackAggregateBps,
      protocolDiagnostics: _summarizeProtocols(
        protocols,
        activeTransportId: activeTransportId,
      ),
      endpointDiagnostics: _summarizeEndpoints(
        endpoints,
        activeRelayId: _firstString(json, const [
          'active_relay_id',
          'active_relay',
        ]),
        activeTransportId: activeTransportId,
      ),
    );
  }

  static String _jsonPayload(String raw) {
    if (raw.startsWith('{') && raw.endsWith('}')) {
      return raw;
    }
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  static RuntimeStatusSnapshot? _tryParseLineStatus(String raw) {
    final header = <String, Object?>{};
    final protocols = <Map<String, Object?>>[];
    final endpoints = <Map<String, Object?>>[];

    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final fields = _parseKeyValueLine(line);
      if (fields.isEmpty) {
        continue;
      }

      if (fields.containsKey('endpoint')) {
        endpoints.add({
          ...fields,
          'id': fields['endpoint'],
          if (fields.containsKey('proto')) 'transport': fields['proto'],
        });
      } else if (fields.containsKey('proto')) {
        protocols.add({
          ...fields,
          'id': fields['proto'],
        });
      } else {
        header.addAll(fields);
      }
    }

    if (header.isEmpty && protocols.isEmpty && endpoints.isEmpty) {
      return null;
    }

    return fromJson({
      ...header,
      'protocols': protocols,
      'endpoints': endpoints,
    });
  }

  static Map<String, Object?> _parseKeyValueLine(String line) {
    final fields = <String, Object?>{};
    for (final match in RegExp(r'([A-Za-z0-9_]+)=([^\s]+)').allMatches(line)) {
      fields[match.group(1)!] = match.group(2)!;
    }
    return fields;
  }

  static List<String> _summarizeProtocols(
    List<Map<String, Object?>> protocols, {
    required String activeTransportId,
  }) {
    final rows = <_ProtocolDiagnosticRow>[];
    for (final item in protocols) {
      final id = _firstString(item, const [
        'id',
        'protocol',
        'protocol_id',
        'transport',
        'proto',
      ]);
      if (id.isEmpty) {
        continue;
      }

      final parts = <String>[];
      final current = id == activeTransportId ||
          _anyBool(item, const ['active', 'selected', 'current']);
      if (current) {
        parts.add('active');
      }
      final rttMs = _firstPositiveDouble(item, _rttFields);
      if (rttMs > 0) {
        parts.add('${rttMs.round()} ms');
      }
      final rate = _firstPositiveDouble(item, _aggregateRateFields);
      if (rate > 0) {
        parts.add(formatRate(rate));
      }
      final failures = _firstPositiveInt(item, const [
        'failures',
        'failure_count',
        'consecutive_failures',
      ]);
      if (failures != null) {
        parts.add('$failures fail');
      }

      rows.add(
        _ProtocolDiagnosticRow(
          current: current,
          text: parts.isEmpty ? id : '$id: ${parts.join(', ')}',
        ),
      );
    }

    rows.sort((left, right) {
      if (left.current == right.current) {
        return 0;
      }
      return left.current ? -1 : 1;
    });
    return rows.map((row) => row.text).take(_maxDiagnosticRows).toList();
  }

  static List<String> _summarizeEndpoints(
    List<Map<String, Object?>> endpoints, {
    required String activeRelayId,
    required String activeTransportId,
  }) {
    final rows = <_EndpointDiagnosticRow>[];
    for (var index = 0; index < endpoints.length; index += 1) {
      final item = endpoints[index];
      final relayId = _firstString(item, const [
        'relay_id',
        'relay',
        'relayId',
        'id',
      ]);
      final transportId = _firstString(item, const [
        'transport',
        'proto',
        'protocol',
        'protocol_id',
        'protocolId',
      ]);
      final current = _anyBool(item, const ['active', 'selected', 'current']) ||
          (relayId.isNotEmpty &&
              relayId == activeRelayId &&
              (transportId.isEmpty || transportId == activeTransportId));
      final name = [
        if (relayId.isNotEmpty) 'relay $relayId',
        if (transportId.isNotEmpty) transportId,
      ].join(' / ');
      final parts = <String>[];

      final rank = _firstPositiveInt(item, const ['rank']);
      if (rank != null) {
        parts.add('rank $rank');
      }
      final score = _firstPositiveDouble(item, const ['score']);
      if (score > 0) {
        parts.add('score ${score.toStringAsFixed(2)}');
      }
      final rttMs = _firstPositiveDouble(item, _rttFields);
      if (rttMs > 0) {
        parts.add('${rttMs.round()} ms');
      }
      final rate = _firstPositiveDouble(item, _aggregateRateFields);
      if (rate > 0) {
        parts.add(formatRate(rate));
      }

      rows.add(
        _EndpointDiagnosticRow(
          current: current,
          text: '${current ? 'current ' : ''}'
              '${name.isNotEmpty ? name : 'endpoint ${index + 1}'}'
              '${parts.isNotEmpty ? ': ${parts.join(', ')}' : ''}',
        ),
      );
    }

    rows.sort((left, right) {
      if (left.current == right.current) {
        return 0;
      }
      return left.current ? -1 : 1;
    });
    return rows.map((row) => row.text).take(_maxDiagnosticRows).toList();
  }

  static String formatRate(double bps) {
    if (bps >= 1000000000) {
      return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
    }
    if (bps >= 1000000) {
      return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    }
    if (bps >= 1000) {
      return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    }
    return '${bps.round()} bps';
  }

  static List<Map<String, Object?>> _listOfMaps(Object? raw) {
    if (raw is! Iterable) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map)
          {
            for (final entry in item.entries) entry.key.toString(): entry.value,
          },
    ];
  }

  static String _firstString(Map<String, Object?> map, List<String> fields) {
    for (final field in fields) {
      final value = _stringValue(map[field]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _stringValue(Object? raw) => raw?.toString().trim() ?? '';

  static bool _anyBool(Map<String, Object?> map, List<String> fields) {
    for (final field in fields) {
      final raw = map[field];
      if (raw is bool && raw) {
        return true;
      }
      if (raw is num && raw != 0) {
        return true;
      }
      final normalized = raw?.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
    }
    return false;
  }

  static int? _firstPositiveInt(Map<String, Object?> map, List<String> fields) {
    for (final field in fields) {
      final raw = map[field];
      final value = raw is num ? raw.toInt() : int.tryParse('$raw'.trim());
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }

  static double _maxFirstPositiveDouble(
    List<Map<String, Object?>> maps,
    List<String> fields,
  ) {
    var maxValue = 0.0;
    for (final map in maps) {
      final value = _firstPositiveDouble(map, fields);
      if (value > maxValue) {
        maxValue = value;
      }
    }
    return maxValue;
  }

  static double _firstPositiveDouble(
    Map<String, Object?> map,
    List<String> fields,
  ) {
    for (final field in fields) {
      final value = _positiveDouble(map[field]);
      if (value > 0) {
        return value;
      }
    }
    for (final objectName in _nestedMetricObjects) {
      final raw = map[objectName];
      if (raw is Map) {
        final nested = {
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        };
        final value = _firstPositiveDouble(nested, fields);
        if (value > 0) {
          return value;
        }
      }
    }
    return 0;
  }

  static double _positiveDouble(Object? raw) {
    final normalized = '$raw'.trim();
    if (normalized == '-' || normalized.isEmpty) {
      return 0;
    }
    final value = raw is num ? raw.toDouble() : double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite || value <= 0) {
      return 0;
    }
    return value;
  }

  static double _maxDouble(double left, double right) {
    return left > right ? left : right;
  }

  static const _maxDiagnosticRows = 4;
  static const _uploadRateFields = [
    'upload_bps',
    'upload_throughput_bps',
    'uplink_bps',
    'tx_bps',
    'send_bps',
    'up',
  ];
  static const _downloadRateFields = [
    'download_bps',
    'download_throughput_bps',
    'downlink_bps',
    'rx_bps',
    'receive_bps',
    'down',
  ];
  static const _aggregateRateFields = [
    'aggregate_throughput_bps',
    'throughput_bps',
    'quick_probe_throughput_bps',
    'bps',
    'throughput',
    'quick',
  ];
  static const _rttFields = [
    'rtt_ms',
    'rtt',
    'latency_ms',
    'connect_latency_ms',
  ];
  static const _nestedMetricObjects = [
    'metrics',
    'measurement',
    'measurements',
    'quick_probe',
    'probe',
    'throughput',
  ];
}

class _EndpointDiagnosticRow {
  const _EndpointDiagnosticRow({
    required this.current,
    required this.text,
  });

  final bool current;
  final String text;
}

class _ProtocolDiagnosticRow {
  const _ProtocolDiagnosticRow({
    required this.current,
    required this.text,
  });

  final bool current;
  final String text;
}

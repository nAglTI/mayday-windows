enum TransportMode {
  auto,
  autoLowCpu,
  tcp,
  utp,
  ws,
  https,
  // Retained only to recover saved profiles; core 2.1.2 removed this carrier.
  rawUdp,
  rawUdpV2;

  String get wireValue => switch (this) {
        TransportMode.auto => 'auto',
        TransportMode.autoLowCpu => 'auto-lowcpu',
        TransportMode.tcp => 'tcp',
        TransportMode.utp => 'utp',
        TransportMode.ws => 'ws',
        TransportMode.https => 'https',
        TransportMode.rawUdp => 'udp',
        TransportMode.rawUdpV2 => 'raw-udp-v2',
      };

  static TransportMode fromWireValue(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'auto-lowcpu' => TransportMode.autoLowCpu,
      'tcp' || 'bt-tcp' => TransportMode.tcp,
      'utp' || 'bt-utp' => TransportMode.utp,
      'ws' => TransportMode.ws,
      'https' || 'rest' || 'https-rest' => TransportMode.https,
      'udp' || 'rawudp' || 'udp-raw' || 'raw-udp' => TransportMode.rawUdp,
      'raw-udp-v2' => TransportMode.rawUdpV2,
      _ => TransportMode.auto,
    };
  }

  static bool supportsWireValue(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return true;
    }
    return switch (value) {
      'auto' ||
      'auto-lowcpu' ||
      'tcp' ||
      'bt-tcp' ||
      'utp' ||
      'bt-utp' ||
      'ws' ||
      'https' ||
      'rest' ||
      'https-rest' ||
      'raw-udp-v2' =>
        true,
      _ => false,
    };
  }
}

class TransportConfig {
  const TransportConfig({
    this.mode = TransportMode.auto,
    this.extraFields = const {},
  });

  final TransportMode mode;
  final Map<String, Object?> extraFields;

  TransportConfig copyWith({
    TransportMode? mode,
    Map<String, Object?>? extraFields,
  }) {
    return TransportConfig(
      mode: mode ?? this.mode,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}

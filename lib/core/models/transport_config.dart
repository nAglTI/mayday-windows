enum TransportMode {
  auto,
  tcp,
  utp,
  ws,
  https,
  rawUdp;

  String get wireValue => switch (this) {
        TransportMode.auto => 'auto',
        TransportMode.tcp => 'tcp',
        TransportMode.utp => 'utp',
        TransportMode.ws => 'ws',
        TransportMode.https => 'https',
        TransportMode.rawUdp => 'udp',
      };

  static TransportMode fromWireValue(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'tcp' || 'bt-tcp' => TransportMode.tcp,
      'utp' || 'bt-utp' => TransportMode.utp,
      'ws' => TransportMode.ws,
      'https' || 'rest' || 'https-rest' => TransportMode.https,
      'udp' || 'rawudp' || 'raw-udp' => TransportMode.rawUdp,
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
      'tcp' ||
      'bt-tcp' ||
      'utp' ||
      'bt-utp' ||
      'ws' ||
      'https' ||
      'rest' ||
      'https-rest' ||
      'udp' ||
      'rawudp' ||
      'raw-udp' =>
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

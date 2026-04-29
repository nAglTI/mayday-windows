enum TransportMode {
  auto,
  tcp,
  utp;

  String get wireValue => switch (this) {
        TransportMode.auto => 'auto',
        TransportMode.tcp => 'tcp',
        TransportMode.utp => 'utp',
      };

  static TransportMode fromWireValue(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'tcp' => TransportMode.tcp,
      'utp' => TransportMode.utp,
      _ => TransportMode.auto,
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

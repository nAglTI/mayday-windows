enum PacketPaddingMode {
  off,
  minimal,
  extreme,
  custom;

  String get wireValue => this == custom ? '' : name;

  static PacketPaddingMode fromWireValue(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'off' => off,
      'minimal' => minimal,
      'extreme' => extreme,
      _ => custom,
    };
  }
}

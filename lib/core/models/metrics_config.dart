class MetricsConfig {
  const MetricsConfig({
    this.enabled = true,
    this.windowSeconds = 600,
    this.fileEnabled = false,
    this.fileDir = '',
    this.extraFields = const {},
  });

  final bool enabled;
  final int windowSeconds;
  final bool fileEnabled;
  final String fileDir;
  final Map<String, Object?> extraFields;

  MetricsConfig copyWith({
    bool? enabled,
    int? windowSeconds,
    bool? fileEnabled,
    String? fileDir,
    Map<String, Object?>? extraFields,
  }) {
    return MetricsConfig(
      enabled: enabled ?? this.enabled,
      windowSeconds: windowSeconds ?? this.windowSeconds,
      fileEnabled: fileEnabled ?? this.fileEnabled,
      fileDir: fileDir ?? this.fileDir,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}

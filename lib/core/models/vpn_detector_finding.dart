class VpnDetectorFinding {
  const VpnDetectorFinding({
    required this.score,
    required this.label,
    required this.rootName,
    required this.rootPath,
    required this.source,
    required this.scannedFiles,
    required this.signals,
    required this.exeCandidates,
  });

  final int score;
  final String label;
  final String rootName;
  final String rootPath;
  final String source;
  final int scannedFiles;
  final List<String> signals;
  final List<String> exeCandidates;

  factory VpnDetectorFinding.fromJson(Map<String, Object?> json) {
    return VpnDetectorFinding(
      score: _readInt(json['score']),
      label: json['label']?.toString() ?? '',
      rootName: json['rootName']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      scannedFiles: _readInt(json['scannedFiles']),
      signals: _readStringList(json['signals']),
      exeCandidates: _readStringList(json['exeCandidates']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const [];
    }

    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }
}

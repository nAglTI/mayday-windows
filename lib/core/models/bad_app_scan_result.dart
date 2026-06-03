import 'bad_app_finding.dart';

class BadAppScanResult {
  const BadAppScanResult({
    required this.scannedAt,
    required this.findings,
  });

  final DateTime scannedAt;
  final List<BadAppFinding> findings;

  factory BadAppScanResult.fromJson(Map<String, Object?> json) {
    final scannedAtText = json['scannedAt']?.toString();
    final scannedAt = scannedAtText == null
        ? null
        : DateTime.tryParse(scannedAtText)?.toLocal();
    if (scannedAt == null) {
      throw const FormatException('Bad app scan result has no scannedAt.');
    }

    final rawFindings = json['findings'];
    final findings = rawFindings is Iterable
        ? [
            for (final item in rawFindings)
              if (item is Map)
                BadAppFinding.fromJson(Map<String, Object?>.from(item)),
          ]
        : const <BadAppFinding>[];

    return BadAppScanResult(
      scannedAt: scannedAt,
      findings: findings,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'scannedAt': scannedAt.toUtc().toIso8601String(),
      'findings': [
        for (final finding in findings) finding.toJson(),
      ],
    };
  }
}

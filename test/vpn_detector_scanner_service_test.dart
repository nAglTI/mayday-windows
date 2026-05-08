import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/services/vpn_detector_scanner_service.dart';

void main() {
  test('parses VPN detector scanner JSON findings', () {
    const raw = '''
{
  "findings": [
    {
      "score": 85,
      "label": "spyware-like VPN discovery signals",
      "rootName": "Example",
      "rootPath": "C:\\\\Program Files\\\\Example",
      "source": "registry HKLM 64",
      "scannedFiles": 42,
      "signals": ["RAS API", "VPN telemetry fields"],
      "exeCandidates": ["C:\\\\Program Files\\\\Example\\\\example.exe"]
    }
  ]
}
''';

    final findings = VpnDetectorScannerService.parseFindingsJson(raw);

    expect(findings, hasLength(1));
    expect(findings.single.score, 85);
    expect(findings.single.rootName, 'Example');
    expect(findings.single.signals, contains('RAS API'));
    expect(
      findings.single.exeCandidates.single,
      r'C:\Program Files\Example\example.exe',
    );
  });
}

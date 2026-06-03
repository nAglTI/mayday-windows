import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/services/bad_app_scanner_service.dart';

void main() {
  test('parses bad app scanner JSON findings', () {
    const raw = '''
{
  "findings": [
    {
      "category": "installed_program",
      "name": "Yandex Browser",
      "path": "C:\\\\Users\\\\user\\\\AppData\\\\Local\\\\Yandex",
      "publisher": "Yandex LLC",
      "version": "1.2.3",
      "status": "",
      "state": "",
      "matchedKeywords": ["yandex"]
    },
    {
      "category": "service",
      "name": "Alice Update Service",
      "path": "alice_update",
      "publisher": "",
      "version": "",
      "status": "Running",
      "state": "",
      "matchedKeywords": "alice"
    },
    {
      "category": "executable_file",
      "name": "alisa.exe",
      "path": "C:\\\\Program Files\\\\Example\\\\alisa.exe",
      "publisher": "Example LLC",
      "version": "4.5.6",
      "status": "",
      "state": "",
      "matchedKeywords": ["alisa"]
    }
  ]
}
''';

    final findings = BadAppScannerService.parseFindingsJson(raw);

    expect(findings, hasLength(3));
    expect(findings.first.category, 'installed_program');
    expect(findings.first.title, 'Yandex Browser');
    expect(findings.first.matchedKeywords, contains('yandex'));
    expect(findings[1].category, 'service');
    expect(findings[1].matchedKeywords, contains('alice'));
    expect(findings.last.category, 'executable_file');
    expect(findings.last.title, 'alisa.exe');
  });

  test('deduplicates repeated scanner findings', () {
    const raw = '''
{
  "findings": [
    {
      "category": "scheduled_task",
      "name": "YandexUpdateTask",
      "path": "\\\\Yandex\\\\",
      "matchedKeywords": ["yandex"]
    },
    {
      "category": "scheduled_task",
      "name": "YandexUpdateTask",
      "path": "\\\\Yandex\\\\",
      "matchedKeywords": ["yandex"]
    }
  ]
}
''';

    final findings = BadAppScannerService.parseFindingsJson(raw);

    expect(findings, hasLength(1));
    expect(findings.single.category, 'scheduled_task');
  });

  test('parses base64 encoded PowerShell scanner payload', () {
    const raw = '''
{
  "findings": [
    {
      "category": "installed_program",
      "name": "Яндекс",
      "matchedKeywords": ["яндекс"]
    }
  ]
}
''';
    final encoded = base64Encode(utf8.encode(raw));

    final findings = BadAppScannerService.parseFindingsPayload(encoded);

    expect(findings, hasLength(1));
    expect(findings.single.title, 'Яндекс');
    expect(findings.single.matchedKeywords, contains('яндекс'));
  });

  test(
    'runs PowerShell scanner without text encoding failures on Windows',
    () async {
      final findings = await BadAppScannerService().scan();

      expect(findings, isA<List>());
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'finds HKCU uninstall registry entries on Windows',
    () async {
      const keyPath =
          r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MaydayScannerFalsePositiveTest';
      await _runPowerShell('''
Remove-Item '$keyPath' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path '$keyPath' -Force | Out-Null
New-ItemProperty -Path '$keyPath' -Name DisplayName -Value 'Yandex Scanner Fixture' -PropertyType String -Force | Out-Null
New-ItemProperty -Path '$keyPath' -Name Publisher -Value 'Mayday Test Fixture' -PropertyType String -Force | Out-Null
New-ItemProperty -Path '$keyPath' -Name DisplayVersion -Value '1.0.0' -PropertyType String -Force | Out-Null
New-ItemProperty -Path '$keyPath' -Name InstallLocation -Value "\$env:LOCALAPPDATA\\MaydayScannerFalsePositiveTest" -PropertyType String -Force | Out-Null
''');

      try {
        final findings = await BadAppScannerService().scan();

        expect(
          findings.any((finding) => finding.name == 'Yandex Scanner Fixture'),
          isTrue,
          reason: findings
              .map(
                (finding) =>
                    '${finding.category}|${finding.name}|${finding.path}',
              )
              .join('\n'),
        );
      } finally {
        await _runPowerShell(
          "Remove-Item '$keyPath' -Recurse -Force -ErrorAction SilentlyContinue",
        );
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

Future<void> _runPowerShell(String script) async {
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ],
  );

  if (result.exitCode != 0) {
    throw ProcessException(
      'powershell.exe',
      const [],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}

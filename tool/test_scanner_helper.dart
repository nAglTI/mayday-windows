import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  final repoRoot = resolveRepoRoot();
  final scannerPath = optionValue(
    args,
    '--scanner',
    defaultValue: p.join(
      repoRoot,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
      'mdschelper.exe',
    ),
  );
  final keepFixture = hasFlag(args, '--keep-fixture');

  final scanner = File(scannerPath);
  if (!scanner.existsSync()) {
    throw StateError(
      'Scanner helper not found: $scannerPath\n'
      'Run tool/build_windows_release.dart first, or pass --scanner.',
    );
  }

  final fixtureRoot = await Directory.systemTemp.createTemp(
    'mayday_scanner_fixture_',
  );
  try {
    final riskyRoot = Directory(p.join(fixtureRoot.path, 'RiskyApp'));
    final cleanRoot = Directory(p.join(fixtureRoot.path, 'CleanApp'));
    await riskyRoot.create(recursive: true);
    await cleanRoot.create(recursive: true);

    await File(p.join(riskyRoot.path, 'risky.exe')).writeAsBytes(
      ascii.encode(
        'RasEnumConnections GetAdaptersAddresses WireGuard vpn_enabled',
      ),
      flush: true,
    );
    await File(p.join(cleanRoot.path, 'clean.exe')).writeAsBytes(
      ascii.encode('ordinary desktop application'),
      flush: true,
    );

    final riskyFindings = await _runScanner(
      scannerPath,
      [
        '--path',
        riskyRoot.path,
        '--paths-only',
        '--json',
        '--min-score',
        '50',
        '--max-file-mb',
        '1',
        '--max-files-per-root',
        '50',
      ],
    );
    if (riskyFindings.isEmpty) {
      throw StateError('Expected one risky finding, got none.');
    }

    final risky = riskyFindings.single;
    final riskyScore = _readInt(risky['score']);
    final riskySignals = _readStringList(risky['signals']);
    final exeCandidates = _readStringList(risky['exeCandidates']);
    if (riskyScore < 50) {
      throw StateError('Expected score >= 50, got $riskyScore.');
    }
    if (!riskySignals.contains('RAS API') ||
        !riskySignals.contains('VPN telemetry fields')) {
      throw StateError(
          'Expected RAS and telemetry signals, got $riskySignals.');
    }
    if (!exeCandidates.any((path) => p.basename(path) == 'risky.exe')) {
      throw StateError('Expected risky.exe candidate, got $exeCandidates.');
    }

    final cleanFindings = await _runScanner(
      scannerPath,
      [
        '--path',
        cleanRoot.path,
        '--paths-only',
        '--json',
        '--min-score',
        '50',
        '--max-file-mb',
        '1',
        '--max-files-per-root',
        '50',
      ],
    );
    if (cleanFindings.isNotEmpty) {
      throw StateError('Expected clean fixture to have no findings.');
    }

    stdout.writeln('Scanner helper smoke test passed.');
    stdout.writeln('Scanner: $scannerPath');
    stdout.writeln('Fixture: ${fixtureRoot.path}');
    stdout.writeln('Risky score: $riskyScore');
    stdout.writeln('Risky signals: ${riskySignals.join(', ')}');
  } finally {
    if (!keepFixture && fixtureRoot.existsSync()) {
      await fixtureRoot.delete(recursive: true);
    }
  }
}

Future<List<Map<String, Object?>>> _runScanner(
  String scannerPath,
  List<String> args,
) async {
  final result = await Process.run(scannerPath, args);
  if (result.exitCode != 0) {
    throw ProcessException(
      scannerPath,
      args,
      [
        result.stdout.toString().trim(),
        result.stderr.toString().trim(),
      ].where((line) => line.isNotEmpty).join('\n'),
      result.exitCode,
    );
  }

  final decoded = jsonDecode(result.stdout.toString());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Scanner JSON root must be an object.');
  }
  final findings = decoded['findings'];
  if (findings is! Iterable) {
    return const [];
  }
  return [
    for (final item in findings)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _readStringList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return [
    for (final item in value)
      if (item.toString().trim().isNotEmpty) item.toString().trim(),
  ];
}

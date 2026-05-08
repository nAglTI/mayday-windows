import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/vpn_detector_finding.dart';
import 'runtime_paths_service.dart';

class VpnDetectorScannerService {
  VpnDetectorScannerService({
    RuntimePathsService? runtimePathsService,
    Duration timeout = const Duration(seconds: 120),
  })  : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService(),
        _timeout = timeout;

  static const scannerExecutableName = 'mdschelper.exe';

  final RuntimePathsService _runtimePathsService;
  final Duration _timeout;

  Future<List<VpnDetectorFinding>> scan({
    int minScore = 50,
    bool full = false,
    bool runningOnly = true,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'VPN detector scanner is available on Windows only.');
    }

    final paths = await _runtimePathsService.getPaths();
    final scannerPath = p.join(paths.installRoot, scannerExecutableName);
    if (!await File(scannerPath).exists()) {
      throw StateError('VPN detector scanner is missing: $scannerPath');
    }

    final args = [
      if (runningOnly) '--running-only',
      if (full) '--full',
      '--json',
      '--min-score',
      '$minScore',
      '--max-file-mb',
      '40',
      '--max-files-per-root',
      '400',
      '--max-depth',
      '3',
    ];
    final output = await _runScanner(scannerPath, args);
    final findings = parseFindingsJson(output.stdout);
    return _filterOwnAndSystemFindings(findings, paths.installRoot);
  }

  static List<VpnDetectorFinding> parseFindingsJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('VPN scanner JSON root must be an object.');
    }

    final rawFindings = decoded['findings'];
    if (rawFindings is! Iterable) {
      return const [];
    }

    return [
      for (final item in rawFindings)
        if (item is Map)
          VpnDetectorFinding.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  Future<_ScannerOutput> _runScanner(
    String scannerPath,
    List<String> args,
  ) async {
    final process = await Process.start(
      scannerPath,
      args,
      mode: ProcessStartMode.normal,
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode.timeout(
      _timeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException('VPN detector scanner timed out.', _timeout);
      },
    );
    final output = _ScannerOutput(
      exitCode: exitCode,
      stdout: await stdout,
      stderr: await stderr,
    );

    if (output.exitCode != 0) {
      final details = output.stderr.trim().isEmpty
          ? output.stdout.trim()
          : output.stderr.trim();
      throw StateError(
        'VPN detector scanner failed with exit code ${output.exitCode}: '
        '$details',
      );
    }
    return output;
  }

  List<VpnDetectorFinding> _filterOwnAndSystemFindings(
    List<VpnDetectorFinding> findings,
    String installRoot,
  ) {
    final windowsRoot = Platform.environment['WINDIR'] ??
        Platform.environment['SystemRoot'] ??
        r'C:\Windows';

    return [
      for (final finding in findings)
        if (!_isUnderPath(finding.rootPath, installRoot) &&
            !_isUnderPath(finding.rootPath, windowsRoot) &&
            !finding.exeCandidates
                .any((path) => _isUnderPath(path, installRoot)))
          finding,
    ];
  }

  bool _isUnderPath(String value, String base) {
    if (value.trim().isEmpty || base.trim().isEmpty) {
      return false;
    }

    final normalizedValue = _normalizeWindowsPath(value);
    final normalizedBase = _normalizeWindowsPath(base);
    return normalizedValue == normalizedBase ||
        normalizedValue.startsWith('$normalizedBase\\');
  }

  String _normalizeWindowsPath(String value) {
    return p.normalize(value).replaceAll('/', r'\').toLowerCase();
  }
}

class _ScannerOutput {
  const _ScannerOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

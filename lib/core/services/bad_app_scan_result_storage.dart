import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/bad_app_scan_result.dart';
import 'runtime_paths_service.dart';

class BadAppScanResultStorage {
  BadAppScanResultStorage({RuntimePathsService? runtimePathsService})
      : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService();

  static const _fileName = 'bad_app_scan_result.json';

  final RuntimePathsService _runtimePathsService;

  Future<BadAppScanResult?> load() async {
    try {
      final file = await _fileHandle();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BadAppScanResult.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // Ignore malformed local scan cache and let the next scan replace it.
    }

    return null;
  }

  Future<File> save(BadAppScanResult result) async {
    final paths = await _runtimePathsService.getPaths();
    await _runtimePathsService.ensureMutableDirectories(paths);
    final file = await _fileHandle();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
      flush: true,
    );
    return file;
  }

  Future<File> _fileHandle() async {
    final paths = await _runtimePathsService.getPaths();
    return File(p.join(paths.configDir, _fileName));
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/bad_app_finding.dart';
import 'package:mayday_windows/core/models/bad_app_scan_result.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/bad_app_scan_result_storage.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('saves and loads bad app scan results', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-scan-test-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = BadAppScanResultStorage(
      runtimePathsService: _FakeRuntimePathsService(tempDir.path),
    );
    final result = BadAppScanResult(
      scannedAt: DateTime.utc(2026, 5, 29, 10, 15),
      findings: const [
        BadAppFinding(
          category: 'executable_file',
          name: 'alisa.exe',
          path: r'C:\Program Files\Example\alisa.exe',
          publisher: 'Example LLC',
          version: '1.2.3',
          status: '',
          state: '',
          matchedKeywords: ['alisa'],
        ),
      ],
    );

    await storage.save(result);
    final loaded = await storage.load();

    expect(loaded, isNotNull);
    expect(loaded!.scannedAt.toUtc(), result.scannedAt);
    expect(loaded.findings, hasLength(1));
    expect(loaded.findings.single.path, result.findings.single.path);
    expect(loaded.findings.single.matchedKeywords, ['alisa']);
  });
}

class _FakeRuntimePathsService implements RuntimePathsService {
  const _FakeRuntimePathsService(this.root);

  final String root;

  @override
  Future<RuntimePaths> getPaths() async {
    final configDir = p.join(root, 'config');
    return RuntimePaths(
      installRoot: root,
      runtimeDir: p.join(root, 'runtime'),
      clientExePath: p.join(root, 'runtime', 'mdhelper.exe'),
      mutableRoot: root,
      configDir: configDir,
      configPath: p.join(configDir, 'client.yaml.dpapi'),
    );
  }

  @override
  Future<void> ensureMutableDirectories(RuntimePaths paths) {
    return Directory(paths.configDir).create(recursive: true);
  }

  @override
  Future<List<String>> validateRuntime(RuntimePaths paths) async {
    return const [];
  }
}

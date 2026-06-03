import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/runtime_paths.dart';

class RuntimePathsService {
  const RuntimePathsService();

  static const String _buildVariant = String.fromEnvironment(
    'MAYDAY_BUILD_VARIANT',
    defaultValue: 'local',
  );
  static const String _runtimeExecutableName = 'mdhelper.exe';
  static const String _pipeHelperExecutableName = 'mdpipectl.exe';
  static const String _controlPipePath = r'\\.\pipe\mayday-control';

  Future<RuntimePaths> getPaths() async {
    final installRoot = File(Platform.resolvedExecutable).parent.path;
    final runtimeDir = p.join(installRoot, 'runtime');
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    final mutableRoot = p.join(localAppData, _mutableRootName);
    final configDir = p.join(mutableRoot, 'config');

    return RuntimePaths(
      installRoot: installRoot,
      runtimeDir: runtimeDir,
      clientExePath: p.join(runtimeDir, _runtimeExecutableName),
      pipeHelperExePath: p.join(runtimeDir, _pipeHelperExecutableName),
      controlPipePath: _controlPipePath,
      mutableRoot: mutableRoot,
      configDir: configDir,
      configPath: p.join(configDir, 'client.yaml.dpapi'),
    );
  }

  String get _mutableRootName {
    final normalized = _buildVariant.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'prod') {
      return 'Mayday';
    }
    return 'Mayday-$normalized';
  }

  Future<void> ensureMutableDirectories(RuntimePaths paths) async {
    await Directory(paths.configDir).create(recursive: true);
  }

  Future<List<String>> validateRuntime(RuntimePaths paths) async {
    final requiredFiles = <String>[
      paths.clientExePath,
      paths.pipeHelperExePath,
      p.join(paths.runtimeDir, 'wintun.dll'),
    ];

    final missing = <String>[];
    for (final filePath in requiredFiles) {
      if (!await File(filePath).exists()) {
        missing.add(filePath);
      }
    }
    return missing;
  }
}

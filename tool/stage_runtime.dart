import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  final repoRoot = resolveRepoRoot();
  final platform = RuntimeStagePlatform.parse(
    optionValue(args, '--platform', defaultValue: 'windows'),
  );
  final spec = RuntimeStageSpec.forPlatform(platform);
  final sourceDir = Directory(
    optionValue(
      args,
      '--source-dir',
      defaultValue: spec.defaultSourceDir(repoRoot),
    ),
  );
  final targetDir = Directory(
    optionValue(
      args,
      '--target-dir',
      defaultValue: spec.defaultTargetDir(repoRoot),
    ),
  );
  final clean = hasFlag(args, '--clean');

  if (!sourceDir.existsSync()) {
    throw StateError('Runtime source directory not found: ${sourceDir.path}');
  }

  final stagedFiles = <_ResolvedRuntimeStageFile>[];
  for (final runtimeFile in spec.runtimeFiles) {
    final sourceFile = _resolveSourceFile(sourceDir, runtimeFile);
    if (sourceFile == null) {
      throw StateError(
        'Required runtime file is missing. Expected one of: '
        '${runtimeFile.sourceNames.map((name) => p.join(sourceDir.path, name)).join(', ')}',
      );
    }
    stagedFiles.add(
      _ResolvedRuntimeStageFile(
        sourceFile: sourceFile,
        outputName: runtimeFile.outputName,
      ),
    );
  }

  if (clean && targetDir.existsSync()) {
    await _removeStaleFiles(spec, sourceDir, targetDir, stagedFiles);
  }

  await targetDir.create(recursive: true);
  for (final stagedFile in stagedFiles) {
    final targetFile = File(p.join(targetDir.path, stagedFile.outputName));
    if (!_sameFileContent(stagedFile.sourceFile, targetFile)) {
      await targetFile.parent.create(recursive: true);
      await stagedFile.sourceFile.copy(targetFile.path);
    }
  }

  final reservedNames = <String>{
    for (final runtimeFile in spec.runtimeFiles)
      for (final sourceName in runtimeFile.sourceNames) sourceName,
  };
  await for (final entity in sourceDir.list(recursive: false)) {
    if (entity is! File) {
      continue;
    }

    final fileName = p.basename(entity.path);
    if (reservedNames.contains(fileName)) {
      continue;
    }

    final targetFile = File(p.join(targetDir.path, p.basename(entity.path)));
    if (!_sameFileContent(entity, targetFile)) {
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetFile.path);
    }
  }

  stdout.writeln('Runtime staged to: ${targetDir.path}');
}

Future<void> _removeStaleFiles(
  RuntimeStageSpec spec,
  Directory sourceDir,
  Directory targetDir,
  List<_ResolvedRuntimeStageFile> stagedFiles,
) async {
  final expectedFiles = <String>{
    for (final stagedFile in stagedFiles) stagedFile.outputName,
  };
  await for (final entity in sourceDir.list(recursive: false)) {
    if (entity is File) {
      expectedFiles.add(p.basename(entity.path));
    }
  }
  for (final stagedFile in stagedFiles) {
    for (final alias in [...spec.staleAliases, stagedFile.outputName]) {
      expectedFiles.remove(alias);
    }
    expectedFiles.add(stagedFile.outputName);
  }

  await for (final entity in targetDir.list(recursive: true)) {
    if (entity is! File) {
      continue;
    }

    final relativePath = p.relative(entity.path, from: targetDir.path);
    if (!expectedFiles.contains(relativePath)) {
      await entity.delete();
    }
  }
}

File? _resolveSourceFile(Directory sourceDir, RuntimeStageFile runtimeFile) {
  for (final sourceName in runtimeFile.sourceNames) {
    final sourceFile = File(p.join(sourceDir.path, sourceName));
    if (sourceFile.existsSync()) {
      return sourceFile;
    }
  }
  return null;
}

bool _sameFileContent(File left, File right) {
  if (!right.existsSync()) {
    return false;
  }
  if (left.lengthSync() != right.lengthSync()) {
    return false;
  }

  final leftBytes = left.readAsBytesSync();
  final rightBytes = right.readAsBytesSync();
  for (var index = 0; index < leftBytes.length; index += 1) {
    if (leftBytes[index] != rightBytes[index]) {
      return false;
    }
  }
  return true;
}

enum RuntimeStagePlatform {
  windows,
  macos;

  static RuntimeStagePlatform parse(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'windows' || 'win' => RuntimeStagePlatform.windows,
      'macos' || 'mac' || 'darwin' => RuntimeStagePlatform.macos,
      _ => throw ArgumentError.value(
          value,
          '--platform',
          'Expected one of: windows, macos',
        ),
    };
  }
}

class RuntimeStageSpec {
  const RuntimeStageSpec({
    required this.runtimeFiles,
    required this.sourceDirName,
    required this.targetSegments,
    required this.staleAliases,
  });

  factory RuntimeStageSpec.forPlatform(RuntimeStagePlatform platform) {
    return switch (platform) {
      RuntimeStagePlatform.windows => windows,
      RuntimeStagePlatform.macos => macos,
    };
  }

  static const windows = RuntimeStageSpec(
    sourceDirName: 'build-win',
    targetSegments: ['build', 'runtime-stage'],
    runtimeFiles: [
      RuntimeStageFile(
        outputName: 'mdhelper.exe',
        sourceNames: ['mdhelper.exe', 'vpnclient.exe'],
      ),
      RuntimeStageFile(
        outputName: 'mdpipectl.exe',
        sourceNames: ['mdpipectl.exe', 'vpnpipectl.exe'],
      ),
      RuntimeStageFile(
        outputName: 'wintun.dll',
        sourceNames: ['wintun.dll'],
      ),
    ],
    staleAliases: [
      'vpnclient.exe',
      'vpnpipectl.exe',
      'mdschelper.exe',
    ],
  );

  static const macos = RuntimeStageSpec(
    sourceDirName: 'build-macos',
    targetSegments: ['build', 'runtime-stage', 'macos'],
    runtimeFiles: [
      RuntimeStageFile(
        outputName: 'mdhelper',
        sourceNames: ['mdhelper', 'vpnclient'],
      ),
      RuntimeStageFile(
        outputName: 'mdpipectl',
        sourceNames: ['mdpipectl', 'vpnpipectl'],
      ),
    ],
    staleAliases: [
      'vpnclient',
      'vpnpipectl',
      'mdschelper',
    ],
  );

  final List<RuntimeStageFile> runtimeFiles;
  final String sourceDirName;
  final List<String> targetSegments;
  final List<String> staleAliases;

  String defaultSourceDir(String repoRoot) {
    return p.join(repoRoot, sourceDirName);
  }

  String defaultTargetDir(String repoRoot) {
    return p.joinAll([repoRoot, ...targetSegments]);
  }
}

class RuntimeStageFile {
  const RuntimeStageFile({
    required this.outputName,
    required this.sourceNames,
  });

  final String outputName;
  final List<String> sourceNames;
}

class _ResolvedRuntimeStageFile {
  const _ResolvedRuntimeStageFile({
    required this.sourceFile,
    required this.outputName,
  });

  final File sourceFile;
  final String outputName;
}

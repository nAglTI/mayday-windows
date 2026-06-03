import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  final repoRoot = resolveRepoRoot();
  final sourceDir = Directory(
    optionValue(
      args,
      '--source-dir',
      defaultValue: p.join(repoRoot, 'build-win'),
    ),
  );
  final targetDir = Directory(
    optionValue(
      args,
      '--target-dir',
      defaultValue: p.join(repoRoot, 'build', 'runtime-stage'),
    ),
  );
  final clean = hasFlag(args, '--clean');

  const runtimeFiles = [
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
  ];

  if (!sourceDir.existsSync()) {
    throw StateError('Runtime source directory not found: ${sourceDir.path}');
  }

  final stagedFiles = <_ResolvedRuntimeStageFile>[];
  for (final runtimeFile in runtimeFiles) {
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
    await _removeStaleFiles(sourceDir, targetDir, stagedFiles);
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
    for (final runtimeFile in runtimeFiles)
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
    for (final alias in [
      'vpnclient.exe',
      'vpnpipectl.exe',
      'mdschelper.exe',
      stagedFile.outputName,
    ]) {
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

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

  const requiredFiles = [
    'vpnclient.exe',
    'WinDivert.dll',
    'WinDivert64.sys',
    'wintun.dll',
  ];

  if (!sourceDir.existsSync()) {
    throw StateError('Runtime source directory not found: ${sourceDir.path}');
  }

  for (final fileName in requiredFiles) {
    final sourceFile = File(p.join(sourceDir.path, fileName));
    if (!sourceFile.existsSync()) {
      throw StateError('Required runtime file is missing: ${sourceFile.path}');
    }
  }

  if (clean && targetDir.existsSync()) {
    await _removeStaleFiles(sourceDir, targetDir);
  }

  await targetDir.create(recursive: true);
  await for (final entity in sourceDir.list(recursive: false)) {
    if (entity is! File) {
      continue;
    }

    final targetFile = File(p.join(targetDir.path, p.basename(entity.path)));
    if (!_sameSize(entity, targetFile)) {
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetFile.path);
    }
  }

  stdout.writeln('Runtime staged to: ${targetDir.path}');
}

Future<void> _removeStaleFiles(Directory sourceDir, Directory targetDir) async {
  await for (final entity in targetDir.list(recursive: true)) {
    if (entity is! File) {
      continue;
    }

    final relativePath = p.relative(entity.path, from: targetDir.path);
    final sourceFile = File(p.join(sourceDir.path, relativePath));
    if (!sourceFile.existsSync()) {
      await entity.delete();
    }
  }
}

bool _sameSize(File left, File right) {
  if (!right.existsSync()) {
    return false;
  }
  return left.lengthSync() == right.lengthSync();
}

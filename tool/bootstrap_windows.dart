import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  final repoRoot = resolveRepoRoot();
  final flutterCmd = optionValue(
    args,
    '--flutter-cmd',
    defaultValue: defaultFlutterCommand(repoRoot),
  );
  final windowsDir = Directory(p.join(repoRoot, 'windows'));
  final metadataFile = File(p.join(repoRoot, '.metadata'));

  if (windowsDir.existsSync() && metadataFile.existsSync()) {
    stdout.writeln('Flutter Windows shell already exists.');
    return;
  }

  final tempDir = await Directory.systemTemp.createTemp(
    'mayday_windows_shell_',
  );

  try {
    await runChecked(
      flutterCmd,
      [
        'create',
        '--platforms=windows',
        '--project-name',
        'mayday_windows',
        '--org',
        'org.debs',
        tempDir.path,
      ],
      workingDirectory: repoRoot,
    );

    if (!windowsDir.existsSync()) {
      await _copyDirectory(
          Directory(p.join(tempDir.path, 'windows')), windowsDir);
    }

    if (!metadataFile.existsSync()) {
      await File(p.join(tempDir.path, '.metadata')).copy(metadataFile.path);
    }

    stdout.writeln('Flutter Windows shell bootstrapped.');
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(recursive: true)) {
    final relativePath = p.relative(entity.path, from: source.path);
    final targetPath = p.join(target.path, relativePath);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(targetPath)).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

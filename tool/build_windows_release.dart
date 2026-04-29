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
  final buildName = optionValue(
    args,
    '--build-name',
    defaultValue: defaultBuildName(repoRoot),
  );
  final symbolsDir = optionValue(
    args,
    '--symbols-dir',
    defaultValue: defaultWindowsSymbolsDir(repoRoot, buildName),
  );
  final releaseDir =
      p.join(repoRoot, 'build', 'windows', 'x64', 'runner', 'Release');
  final runtimeTargetDir = p.join(releaseDir, 'runtime');

  await runChecked(
    Platform.resolvedExecutable,
    ['run', 'tool/bootstrap_windows.dart', '--flutter-cmd', flutterCmd],
    workingDirectory: repoRoot,
  );
  await runChecked(flutterCmd, ['pub', 'get'], workingDirectory: repoRoot);
  await runChecked(
    flutterCmd,
    [
      'build',
      'windows',
      '--release',
      '--build-name',
      buildName,
      '--obfuscate',
      '--split-debug-info',
      symbolsDir,
    ],
    workingDirectory: repoRoot,
  );
  await runChecked(
    Platform.resolvedExecutable,
    [
      'run',
      'tool/stage_runtime.dart',
      '--target-dir',
      runtimeTargetDir,
      '--clean',
    ],
    workingDirectory: repoRoot,
  );

  stdout.writeln('Windows release is ready in: $releaseDir');
  stdout.writeln('Obfuscation symbols are in: $symbolsDir');
}

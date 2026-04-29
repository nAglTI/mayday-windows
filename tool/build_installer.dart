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
  final isccPath = resolveIsccPath(
    optionValue(args, '--iscc-path', defaultValue: ''),
  );
  final releaseDir =
      p.join(repoRoot, 'build', 'windows', 'x64', 'runner', 'Release');
  final issPath = p.join(repoRoot, 'installer', 'Mayday.iss');

  await runChecked(
    Platform.resolvedExecutable,
    [
      'run',
      'tool/build_windows_release.dart',
      '--flutter-cmd',
      flutterCmd,
      '--build-name',
      buildName,
      '--symbols-dir',
      symbolsDir,
    ],
    workingDirectory: repoRoot,
  );
  await runChecked(
    isccPath,
    [
      '/DAppVersion=$buildName',
      '/DFlutterReleaseDir=$releaseDir',
      '/DAppExeName=mayday_windows.exe',
      issPath,
    ],
    workingDirectory: repoRoot,
  );

  stdout.writeln('Installer build completed.');
  stdout.writeln('Obfuscation symbols are in: $symbolsDir');
}

import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  final repoRoot = resolveRepoRoot();
  final pubspecVersion = defaultBuildVersion(repoRoot);
  final flutterCmd = optionValue(
    args,
    '--flutter-cmd',
    defaultValue: defaultFlutterCommand(repoRoot),
  );
  final buildVersion = AppBuildVersion.fromParts(
    buildName: optionValue(
      args,
      '--build-name',
      defaultValue: pubspecVersion.buildName,
    ),
    buildNumber: optionValue(
      args,
      '--build-number',
      defaultValue: pubspecVersion.buildNumber,
    ),
  );
  final symbolsDir = optionValue(
    args,
    '--symbols-dir',
    defaultValue: defaultWindowsSymbolsDir(
      repoRoot,
      buildVersion.displayVersion,
    ),
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
      'tool/build_windows_release.dart',
      '--flutter-cmd',
      flutterCmd,
      '--build-name',
      buildVersion.buildName,
      '--build-number',
      buildVersion.buildNumber,
      '--build-variant',
      'prod',
      '--symbols-dir',
      symbolsDir,
    ],
    workingDirectory: repoRoot,
  );
  await runChecked(
    isccPath,
    [
      '/DAppVersion=${buildVersion.displayVersion}',
      '/DAppVersionInfo=${buildVersion.windowsVersion}',
      '/DFlutterReleaseDir=$releaseDir',
      '/DAppExeName=mayday_windows.exe',
      issPath,
    ],
    workingDirectory: repoRoot,
  );

  stdout.writeln('Installer build completed.');
  stdout.writeln('App version: ${buildVersion.displayVersion}');
  stdout.writeln('Obfuscation symbols are in: $symbolsDir');
}

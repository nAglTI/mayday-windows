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
  final buildVariant = optionValue(
    args,
    '--build-variant',
    defaultValue: 'local',
  );
  final releaseDir =
      p.join(repoRoot, 'build', 'windows', 'x64', 'runner', 'Release');
  final runtimeTargetDir = p.join(releaseDir, 'runtime');

  await runChecked(
    Platform.resolvedExecutable,
    ['tool/bootstrap_windows.dart', '--flutter-cmd', flutterCmd],
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
      buildVersion.buildName,
      '--build-number',
      buildVersion.buildNumber,
      '--dart-define=MAYDAY_BUILD_VARIANT=$buildVariant',
      '--dart-define=MAYDAY_APP_VERSION=${buildVersion.displayVersion}',
      '--obfuscate',
      '--split-debug-info',
      symbolsDir,
    ],
    workingDirectory: repoRoot,
  );
  await runChecked(
    Platform.resolvedExecutable,
    [
      'tool/stage_runtime.dart',
      '--target-dir',
      runtimeTargetDir,
      '--clean',
    ],
    workingDirectory: repoRoot,
  );

  stdout.writeln('Windows $buildVariant release is ready in: $releaseDir');
  stdout.writeln('App version: ${buildVersion.displayVersion}');
  stdout.writeln('Obfuscation symbols are in: $symbolsDir');
}

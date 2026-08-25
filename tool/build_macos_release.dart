import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_build_common.dart';

Future<void> main(List<String> args) async {
  if (!Platform.isMacOS) {
    throw UnsupportedError('The macOS release must be built on macOS.');
  }

  final repoRoot = resolveRepoRoot();
  final pubspecVersion = defaultBuildVersion(repoRoot);
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
  final flutterCmd = optionValue(
    args,
    '--flutter-cmd',
    defaultValue: defaultFlutterCommand(repoRoot),
  );
  final goCmd = optionValue(args, '--go-cmd', defaultValue: 'go');
  final coreDir = p.normalize(
    optionValue(
      args,
      '--core-dir',
      defaultValue: Platform.environment['MAYDAY_CORE_DIR'] ??
          p.join(p.dirname(repoRoot), 'mayday-protocol'),
    ),
  );
  final buildVariant = optionValue(
    args,
    '--build-variant',
    defaultValue: 'prod',
  );
  final runtimeSourceDir = p.join(repoRoot, 'build-macos');
  final appPath = p.join(
    repoRoot,
    'build',
    'macos',
    'Build',
    'Products',
    'Release',
    'Mayday.app',
  );

  if (!Directory(coreDir).existsSync()) {
    throw StateError(
      'Mayday core repository not found: $coreDir. '
      'Pass --core-dir or set MAYDAY_CORE_DIR.',
    );
  }

  await Directory(runtimeSourceDir).create(recursive: true);
  final goEnvironment = <String, String>{'CGO_ENABLED': '0'};
  await runChecked(
    goCmd,
    [
      'build',
      '-trimpath',
      '-o',
      p.join(runtimeSourceDir, 'mayday-core'),
      './client',
    ],
    workingDirectory: coreDir,
    environment: goEnvironment,
  );
  await runChecked(
    goCmd,
    [
      'build',
      '-trimpath',
      '-o',
      p.join(runtimeSourceDir, 'maydayctl'),
      './cmd/vpnpipectl',
    ],
    workingDirectory: coreDir,
    environment: goEnvironment,
  );

  await runChecked(
    Platform.resolvedExecutable,
    [
      'tool/stage_runtime.dart',
      '--platform',
      'macos',
      '--source-dir',
      runtimeSourceDir,
      '--clean',
    ],
    workingDirectory: repoRoot,
  );
  await runChecked(flutterCmd, ['pub', 'get'], workingDirectory: repoRoot);
  await runChecked(
    flutterCmd,
    [
      'build',
      'macos',
      '--release',
      '--build-name',
      buildVersion.buildName,
      '--build-number',
      buildVersion.buildNumber,
      '--dart-define=MAYDAY_BUILD_VARIANT=$buildVariant',
      '--dart-define=MAYDAY_APP_VERSION=${buildVersion.displayVersion}',
    ],
    workingDirectory: repoRoot,
  );

  if (!Directory(appPath).existsSync()) {
    throw StateError('Flutter did not produce the expected app: $appPath');
  }

  // This is an ad-hoc signature, not a Developer ID signature. macOS requires
  // Mach-O bundles to be structurally signed even for local distribution.
  await runChecked(
    '/usr/bin/codesign',
    ['--force', '--deep', '--sign', '-', appPath],
    workingDirectory: repoRoot,
  );

  if (hasFlag(args, '--skip-dmg')) {
    stdout.writeln('macOS app is ready: $appPath');
    return;
  }

  final distDir = Directory(p.join(repoRoot, 'dist', 'macos'));
  await distDir.create(recursive: true);
  final dmgPath = p.join(
    distDir.path,
    'Mayday-${buildVersion.displayVersion}.dmg',
  );
  final imageRoot = await Directory.systemTemp.createTemp('mayday-dmg-');
  try {
    final stagedApp = p.join(imageRoot.path, 'Mayday.app');
    await runChecked(
      '/usr/bin/ditto',
      [appPath, stagedApp],
      workingDirectory: repoRoot,
    );
    await Link(p.join(imageRoot.path, 'Applications')).create('/Applications');
    await runChecked(
      '/usr/bin/hdiutil',
      [
        'create',
        '-volname',
        'Mayday',
        '-srcfolder',
        imageRoot.path,
        '-ov',
        '-format',
        'UDZO',
        dmgPath,
      ],
      workingDirectory: repoRoot,
    );
  } finally {
    if (imageRoot.existsSync()) {
      await imageRoot.delete(recursive: true);
    }
  }

  stdout.writeln('macOS app is ready: $appPath');
  stdout.writeln('Unsigned Developer ID DMG is ready: $dmgPath');
}

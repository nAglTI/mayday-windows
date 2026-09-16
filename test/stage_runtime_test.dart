import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../tool/stage_runtime.dart' as runtime_stage;

void main() {
  late Directory tempDir;
  late Directory sourceDir;
  late Directory targetDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mayday-runtime-stage-');
    sourceDir = Directory(p.join(tempDir.path, 'source'));
    targetDir = Directory(p.join(tempDir.path, 'target'));
    await sourceDir.create();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> stage({String platform = 'windows', bool clean = false}) {
    return runtime_stage.main([
      '--platform',
      platform,
      '--source-dir',
      sourceDir.path,
      '--target-dir',
      targetDir.path,
      if (clean) '--clean',
    ]);
  }

  Future<void> write(Directory directory, String name, String contents) async {
    final file = File(p.join(directory.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<void> writeWindowsBundle() async {
    for (final name in [
      'vpnclient.exe',
      'vpnpipectl.exe',
      'wintun.dll',
      'WinDivert.dll',
      'WinDivert64.sys',
    ]) {
      await write(sourceDir, name, 'new $name');
    }
  }

  test('stages renamed helpers, support files and nested licenses', () async {
    await writeWindowsBundle();
    final licensePath = p.join('licenses', 'WinDivert-LICENSE.txt');
    final nestedPath = p.join('licenses', 'upstream', 'SOURCES.md');
    await write(sourceDir, licensePath, 'license');
    await write(sourceDir, nestedPath, 'sources');

    await stage();

    expect(
      await File(p.join(targetDir.path, 'mdhelper.exe')).readAsString(),
      'new vpnclient.exe',
    );
    expect(
      await File(p.join(targetDir.path, 'mdpipectl.exe')).readAsString(),
      'new vpnpipectl.exe',
    );
    for (final name in ['wintun.dll', 'WinDivert.dll', 'WinDivert64.sys']) {
      expect(
        await File(p.join(targetDir.path, name)).readAsString(),
        'new $name',
      );
    }
    expect(await File(p.join(targetDir.path, licensePath)).readAsString(),
        'license');
    expect(await File(p.join(targetDir.path, nestedPath)).readAsString(),
        'sources');
    expect(File(p.join(targetDir.path, 'vpnclient.exe')).existsSync(), isFalse);
    expect(
        File(p.join(targetDir.path, 'vpnpipectl.exe')).existsSync(), isFalse);
  });

  test('clean preserves current nested files and removes stale files',
      () async {
    await writeWindowsBundle();
    final licensePath = p.join('licenses', 'WinDivert-LICENSE.txt');
    final staleLicensePath = p.join('licenses', 'old.txt');
    final nestedAliasPath = p.join('licenses', 'mdschelper.exe');
    await write(sourceDir, licensePath, 'current license');
    await write(sourceDir, nestedAliasPath, 'nested auxiliary file');
    await write(sourceDir, 'mdschelper.exe', 'obsolete source helper');
    await write(sourceDir, 'mayday_vpnscan.exe', 'obsolete scanner');
    await write(targetDir, licensePath, 'old license');
    await write(targetDir, staleLicensePath, 'stale license');
    for (final alias in [
      'vpnclient.exe',
      'vpnpipectl.exe',
      'mdschelper.exe',
      'mayday_vpnscan.exe',
    ]) {
      await write(targetDir, alias, 'old helper');
    }

    await stage(clean: true);
    await stage(clean: true);

    expect(await File(p.join(targetDir.path, licensePath)).readAsString(),
        'current license');
    expect(await File(p.join(targetDir.path, nestedAliasPath)).readAsString(),
        'nested auxiliary file');
    for (final stalePath in [
      staleLicensePath,
      'vpnclient.exe',
      'vpnpipectl.exe',
      'mdschelper.exe',
      'mayday_vpnscan.exe',
    ]) {
      expect(File(p.join(targetDir.path, stalePath)).existsSync(), isFalse);
    }
  });

  test('prefers existing Mayday helper names when both aliases exist',
      () async {
    await writeWindowsBundle();
    await write(sourceDir, 'mdhelper.exe', 'Mayday client');
    await write(sourceDir, 'mdpipectl.exe', 'Mayday controller');

    await stage();

    expect(
      await File(p.join(targetDir.path, 'mdhelper.exe')).readAsString(),
      'Mayday client',
    );
    expect(
      await File(p.join(targetDir.path, 'mdpipectl.exe')).readAsString(),
      'Mayday controller',
    );
  });

  for (final requiredFile in ['WinDivert.dll', 'WinDivert64.sys']) {
    test('missing $requiredFile fails before cleaning the target', () async {
      await writeWindowsBundle();
      await File(p.join(sourceDir.path, requiredFile)).delete();
      await write(targetDir, 'existing.txt', 'preserve on validation failure');

      await expectLater(
        stage(clean: true),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(requiredFile),
        )),
      );

      expect(
        await File(p.join(targetDir.path, 'existing.txt')).readAsString(),
        'preserve on validation failure',
      );
    });
  }

  test('macOS staging keeps platform requirements and nested licenses',
      () async {
    await write(sourceDir, 'vpnclient', 'mac client');
    await write(sourceDir, 'vpnpipectl', 'mac controller');
    final licensePath = p.join('licenses', 'LICENSE.txt');
    await write(sourceDir, licensePath, 'mac license');

    await stage(platform: 'macos', clean: true);

    expect(await File(p.join(targetDir.path, 'mdhelper')).readAsString(),
        'mac client');
    expect(await File(p.join(targetDir.path, 'mdpipectl')).readAsString(),
        'mac controller');
    expect(await File(p.join(targetDir.path, licensePath)).readAsString(),
        'mac license');
  });
}

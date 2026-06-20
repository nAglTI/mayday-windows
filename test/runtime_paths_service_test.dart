import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('builds Windows runtime paths', () async {
    const service = RuntimePathsService(
      platform: RuntimePlatform.windows,
      environment: {'LOCALAPPDATA': r'C:\Users\tester\AppData\Local'},
      resolvedExecutable: r'C:\Program Files\Mayday\mayday_windows.exe',
    );

    final paths = await service.getPaths();

    expect(paths.installRoot, r'C:\Program Files\Mayday');
    expect(paths.runtimeDir, r'C:\Program Files\Mayday\runtime');
    expect(
        paths.clientExePath, r'C:\Program Files\Mayday\runtime\mdhelper.exe');
    expect(
      paths.pipeHelperExePath,
      r'C:\Program Files\Mayday\runtime\mdpipectl.exe',
    );
    expect(paths.controlPipePath, r'\\.\pipe\mayday-control');
    expect(
      paths.mutableRoot,
      r'C:\Users\tester\AppData\Local\Mayday-local',
    );
    expect(
      paths.configPath,
      r'C:\Users\tester\AppData\Local\Mayday-local\config\client.yaml.dpapi',
    );
  });

  test('builds macOS runtime paths from an app bundle', () async {
    const service = RuntimePathsService(
      platform: RuntimePlatform.macos,
      environment: {'HOME': '/Users/tester'},
      resolvedExecutable: '/Applications/Mayday.app/Contents/MacOS/Mayday',
    );

    final paths = await service.getPaths();

    expect(paths.installRoot, '/Applications/Mayday.app/Contents/Resources');
    expect(
      paths.runtimeDir,
      '/Applications/Mayday.app/Contents/Resources/runtime',
    );
    expect(
      paths.clientExePath,
      '/Applications/Mayday.app/Contents/Resources/runtime/mdhelper',
    );
    expect(
      paths.pipeHelperExePath,
      '/Applications/Mayday.app/Contents/Resources/runtime/mdpipectl',
    );
    expect(
      paths.controlPipePath,
      '/Users/tester/Library/Application Support/Mayday-local/'
      'mayday-control.sock',
    );
    expect(
      paths.configPath,
      '/Users/tester/Library/Application Support/Mayday-local/config/'
      'client.yaml.keychain',
    );
  });

  test('validates Windows runtime support files', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-runtime-');
    addTearDown(() => tempDir.delete(recursive: true));
    final runtimeDir = Directory(p.join(tempDir.path, 'runtime'));
    await runtimeDir.create(recursive: true);
    final paths = RuntimePaths(
      installRoot: tempDir.path,
      runtimeDir: runtimeDir.path,
      clientExePath: p.join(runtimeDir.path, 'mdhelper.exe'),
      pipeHelperExePath: p.join(runtimeDir.path, 'mdpipectl.exe'),
      mutableRoot: tempDir.path,
      configDir: p.join(tempDir.path, 'config'),
      configPath: p.join(tempDir.path, 'config', 'client.yaml.dpapi'),
    );
    const service = RuntimePathsService(platform: RuntimePlatform.windows);

    expect(
      await service.validateRuntime(paths),
      containsAll([
        paths.clientExePath,
        paths.pipeHelperExePath,
        p.join(paths.runtimeDir, 'wintun.dll'),
      ]),
    );

    await File(paths.clientExePath).writeAsString('');
    await File(paths.pipeHelperExePath).writeAsString('');
    await File(p.join(paths.runtimeDir, 'wintun.dll')).writeAsString('');

    expect(await service.validateRuntime(paths), isEmpty);
  });

  test('validates macOS runtime without Wintun', () async {
    final tempDir = await Directory.systemTemp.createTemp('mayday-runtime-');
    addTearDown(() => tempDir.delete(recursive: true));
    final runtimeDir = Directory(p.join(tempDir.path, 'runtime'));
    await runtimeDir.create(recursive: true);
    final paths = RuntimePaths(
      installRoot: tempDir.path,
      runtimeDir: runtimeDir.path,
      clientExePath: p.join(runtimeDir.path, 'mdhelper'),
      pipeHelperExePath: p.join(runtimeDir.path, 'mdpipectl'),
      mutableRoot: tempDir.path,
      configDir: p.join(tempDir.path, 'config'),
      configPath: p.join(tempDir.path, 'config', 'client.yaml.keychain'),
    );
    const service = RuntimePathsService(platform: RuntimePlatform.macos);

    expect(
      await service.validateRuntime(paths),
      containsAll([paths.clientExePath, paths.pipeHelperExePath]),
    );

    await File(paths.clientExePath).writeAsString('');
    await File(paths.pipeHelperExePath).writeAsString('');

    expect(await service.validateRuntime(paths), isEmpty);
  });
}

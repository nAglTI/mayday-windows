import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late RuntimePaths paths;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mayday-core-version-');
    paths = RuntimePaths(
      installRoot: tempDir.path,
      runtimeDir: tempDir.path,
      clientExePath: p.join(tempDir.path, 'mdhelper.exe'),
      pipeHelperExePath: p.join(tempDir.path, 'mdpipectl.exe'),
      mutableRoot: tempDir.path,
      configDir: p.join(tempDir.path, 'config'),
      configPath: p.join(tempDir.path, 'config', 'client.yaml.dpapi'),
    );
    await File(paths.clientExePath).writeAsString('');
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('asks the installed core for its version without starting a VPN',
      () async {
    final process = _VersionProcess(output: '2.1.2\r\n');
    final service = RuntimePathsService(
      versionProcessStarter: (executable, arguments, {workingDirectory}) async {
        expect(executable, paths.clientExePath);
        expect(arguments, ['-version']);
        expect(workingDirectory, paths.runtimeDir);
        return process;
      },
    );

    expect(await service.getCoreVersion(paths), '2.1.2');
    expect(process.wasKilled, isFalse);
  });

  test('accepts a version containing prerelease and build metadata', () async {
    final service = _serviceFor(
      _VersionProcess(output: '2.1.2-rc.1+custom.4\n'),
    );

    expect(await service.getCoreVersion(paths), '2.1.2-rc.1+custom.4');
  });

  test('reports unknown when old binaries return help or noisy output',
      () async {
    for (final output in [
      '',
      'Usage: mdhelper -config client.yaml',
      'core_version=2.1.2',
      '2.1.2\nstarting...',
      '2.1.2\n2.1.2',
    ]) {
      expect(
        await _serviceFor(_VersionProcess(output: output))
            .getCoreVersion(paths),
        isNull,
      );
    }
  });

  test('reports unknown on a failed version command', () async {
    final service = _serviceFor(
      _VersionProcess(output: '2.1.2', exitCode: Future.value(1)),
    );

    expect(await service.getCoreVersion(paths), isNull);
  });

  test('terminates a version command that does not finish', () async {
    final process = _VersionProcess(
      output: '2.1.2',
      exitCode: Completer<int>().future,
    );
    final service = _serviceFor(process);

    expect(await service.getCoreVersion(paths), isNull);
    expect(process.wasKilled, isTrue);
  });

  test('reports unknown when process creation fails', () async {
    final service = RuntimePathsService(
      versionProcessStarter: (executable, arguments, {workingDirectory}) async {
        throw ProcessException(executable, arguments, 'Cannot execute');
      },
    );

    expect(await service.getCoreVersion(paths), isNull);
  });

  test('does not execute a missing installed core', () async {
    await File(paths.clientExePath).delete();
    final service = RuntimePathsService(
      versionProcessStarter: (executable, arguments, {workingDirectory}) async {
        fail('A missing core must not be executed.');
      },
    );

    expect(await service.getCoreVersion(paths), isNull);
  });
}

RuntimePathsService _serviceFor(_VersionProcess process) {
  return RuntimePathsService(
    versionProcessStarter: (executable, arguments, {workingDirectory}) async =>
        process,
    versionTimeout: const Duration(milliseconds: 50),
  );
}

class _VersionProcess implements Process {
  _VersionProcess({required String output, Future<int>? exitCode})
      : stdout = Stream.value(utf8.encode(output)),
        exitCode = exitCode ?? Future.value(0);

  bool wasKilled = false;

  @override
  final Future<int> exitCode;

  @override
  final Stream<List<int>> stdout;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    wasKilled = true;
    return true;
  }
}

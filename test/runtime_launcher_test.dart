import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/runtime_diagnostics_logger.dart';
import 'package:mayday_windows/core/services/runtime_launcher.dart';
import 'package:mayday_windows/core/services/runtime_paths_service.dart';

void main() {
  test('attaches to and controls a runtime left by an earlier UI process',
      () async {
    final control = _FakeRuntimeControlClient();
    final launcher = RuntimeLauncher(
      runtimePathsService: const _FakeRuntimePathsService(),
      diagnosticsLogger: const RuntimeDiagnosticsLogger(enabled: false),
      controlClient: control,
    );

    await launcher.attachExistingRuntime();

    expect(launcher.isRunning, isTrue);
    expect(control.commands, ['status']);

    final stopResult = await launcher.stop();

    expect(stopResult.success, isTrue);
    expect(launcher.isRunning, isFalse);
    expect(control.commands, ['status', 'stop']);

    final shutdownResult = await launcher.shutdown();

    expect(shutdownResult.success, isTrue);
    expect(control.commands, ['status', 'stop', 'shutdown']);
  });
}

class _FakeRuntimePathsService extends RuntimePathsService {
  const _FakeRuntimePathsService();

  @override
  Future<RuntimePaths> getPaths() async {
    return const RuntimePaths(
      installRoot: '/Applications/Mayday.app/Contents/Resources',
      runtimeDir: '/Applications/Mayday.app/Contents/Resources/runtime',
      clientExePath:
          '/Applications/Mayday.app/Contents/Resources/runtime/mdhelper',
      pipeHelperExePath:
          '/Applications/Mayday.app/Contents/Resources/runtime/mdpipectl',
      controlPipePath: '/tmp/mayday-control.sock',
      mutableRoot: '/tmp/mayday-test',
      configDir: '/tmp/mayday-test/config',
      configPath: '/tmp/mayday-test/config/profile',
    );
  }
}

class _FakeRuntimeControlClient extends RuntimeControlClient {
  final List<String> commands = [];

  @override
  Future<RuntimeControlResult> send(
    RuntimePaths paths, {
    required String command,
    required Duration waitTimeout,
  }) async {
    commands.add(command);
    return RuntimeControlResult(
      command: command,
      exitCode: 0,
      stdout: command == 'status'
          ? 'state=vpn_connect vpn=active relay=r1 transport=bt-utp exit=n1'
          : 'ok',
      stderr: '',
    );
  }
}

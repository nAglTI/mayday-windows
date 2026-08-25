import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/runtime_paths.dart';
import 'package:mayday_windows/core/services/macos_privileged_runtime.dart';

void main() {
  test('builds an administrator-authorized macOS runtime command', () {
    const paths = RuntimePaths(
      installRoot: '/Applications/Mayday.app/Contents/Resources',
      runtimeDir: '/Applications/Mayday.app/Contents/Resources/runtime',
      clientExePath:
          '/Applications/Mayday.app/Contents/Resources/runtime/mdhelper',
      pipeHelperExePath:
          '/Applications/Mayday.app/Contents/Resources/runtime/mdpipectl',
      controlPipePath:
          '/Users/tester/Library/Application Support/Mayday/mayday.sock',
      mutableRoot: '/Users/tester/Library/Application Support/Mayday',
      configDir: '/Users/tester/Library/Application Support/Mayday/config',
      configPath:
          '/Users/tester/Library/Application Support/Mayday/config/profile',
    );

    final script = buildMacOSPrivilegedRuntimeAppleScript(
      paths: paths,
      configPath:
          '/Users/tester/Library/Application Support/Mayday/config/client.runtime.yaml',
      ownerUid: 501,
      stdoutLogPath:
          '/Users/tester/Library/Application Support/Mayday/logs/core.out.log',
      stderrLogPath:
          '/Users/tester/Library/Application Support/Mayday/logs/core.err.log',
    );

    expect(script, startsWith('do shell script "'));
    expect(script, endsWith('" with administrator privileges'));
    expect(script, contains('-recover-network'));
    expect(script, contains('-control-endpoint'));
    expect(script, contains('-control-owner-uid 501'));
    expect(
      script,
      contains(
        "'/Users/tester/Library/Application Support/Mayday/config/client.runtime.yaml'",
      ),
    );
  });

  test('rejects a negative control socket owner uid', () {
    const paths = RuntimePaths(
      installRoot: '/tmp',
      runtimeDir: '/tmp/runtime',
      clientExePath: '/tmp/runtime/mdhelper',
      mutableRoot: '/tmp',
      configDir: '/tmp/config',
      configPath: '/tmp/config/profile',
    );

    expect(
      () => buildMacOSPrivilegedRuntimeAppleScript(
        paths: paths,
        configPath: '/tmp/config/runtime.yaml',
        ownerUid: -1,
        stdoutLogPath: '/tmp/out.log',
        stderrLogPath: '/tmp/err.log',
      ),
      throwsArgumentError,
    );
  });
}

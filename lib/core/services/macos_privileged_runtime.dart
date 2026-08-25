import 'dart:io';

import '../models/runtime_paths.dart';

class MacOSPrivilegedRuntime {
  const MacOSPrivilegedRuntime();

  Future<Process> start({
    required RuntimePaths paths,
    required String configPath,
    required String stdoutLogPath,
    required String stderrLogPath,
  }) async {
    final ownerUid = await currentUserId();
    final script = buildMacOSPrivilegedRuntimeAppleScript(
      paths: paths,
      configPath: configPath,
      ownerUid: ownerUid,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
    );

    return Process.start(
      '/usr/bin/osascript',
      ['-e', script],
      workingDirectory: paths.runtimeDir,
      mode: ProcessStartMode.normal,
    );
  }

  Future<int> currentUserId() async {
    final result = await Process.run('/usr/bin/id', ['-u']);
    final value = int.tryParse(result.stdout.toString().trim());
    if (result.exitCode != 0 || value == null || value < 0) {
      throw ProcessException(
        '/usr/bin/id',
        const ['-u'],
        _processOutput(result),
        result.exitCode,
      );
    }
    return value;
  }

  String _processOutput(ProcessResult result) {
    return [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
    ].where((value) => value.isNotEmpty).join('\n');
  }
}

String buildMacOSPrivilegedRuntimeAppleScript({
  required RuntimePaths paths,
  required String configPath,
  required int ownerUid,
  required String stdoutLogPath,
  required String stderrLogPath,
}) {
  if (ownerUid < 0) {
    throw ArgumentError.value(ownerUid, 'ownerUid', 'Must not be negative');
  }

  final executable = _quotePosixShellArgument(paths.clientExePath);
  final stdoutLog = _quotePosixShellArgument(stdoutLogPath);
  final stderrLog = _quotePosixShellArgument(stderrLogPath);
  final recoverCommand = '$executable -recover-network';
  final launchCommand = [
    'exec',
    executable,
    '-config',
    _quotePosixShellArgument(configPath),
    '-control-endpoint',
    _quotePosixShellArgument(paths.controlPipePath),
    '-control-owner-uid',
    '$ownerUid',
  ].join(' ');
  final shellCommand = [
    'cd ${_quotePosixShellArgument(paths.runtimeDir)}',
    '$recoverCommand >> $stdoutLog 2>> $stderrLog',
    '$launchCommand >> $stdoutLog 2>> $stderrLog',
  ].join(' && ');
  final escaped = shellCommand
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"');
  return 'do shell script "$escaped" with administrator privileges';
}

String _quotePosixShellArgument(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

import 'dart:io';

class AppAutostartService {
  const AppAutostartService();

  static const taskName = 'Mayday';

  Future<bool> isEnabled() async {
    if (!Platform.isWindows) {
      return false;
    }

    final result = await Process.run(
      'schtasks.exe',
      ['/Query', '/TN', taskName],
    );
    return result.exitCode == 0;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }

    if (enabled) {
      await _createOrUpdateTask();
    } else {
      await _deleteTaskIfExists();
    }
  }

  Future<void> _createOrUpdateTask() async {
    await _runChecked('schtasks.exe', [
      '/Create',
      '/F',
      '/TN',
      taskName,
      '/SC',
      'ONLOGON',
      '/RL',
      'HIGHEST',
      '/TR',
      _taskCommand(),
    ]);
  }

  Future<void> _deleteTaskIfExists() async {
    if (!await isEnabled()) {
      return;
    }

    await _runChecked('schtasks.exe', [
      '/Delete',
      '/F',
      '/TN',
      taskName,
    ]);
  }

  Future<void> _runChecked(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode == 0) {
      return;
    }

    final output = [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
    ].where((line) => line.isNotEmpty).join('\n');

    throw ProcessException(
      executable,
      arguments,
      output.isEmpty ? 'exit code ${result.exitCode}' : output,
      result.exitCode,
    );
  }

  String _taskCommand() {
    final executable = Platform.resolvedExecutable.replaceAll('"', r'\"');
    return '"$executable" --autostart';
  }
}

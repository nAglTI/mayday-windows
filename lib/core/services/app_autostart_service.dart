import 'dart:io';

import 'package:path/path.dart' as p;

class AppAutostartService {
  const AppAutostartService();

  static const String _buildVariant = String.fromEnvironment(
    'MAYDAY_BUILD_VARIANT',
    defaultValue: 'local',
  );

  static String get taskName {
    final normalized = _buildVariant.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'prod') {
      return 'Mayday';
    }
    return 'Mayday-$normalized';
  }

  Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final result = await Process.run(
        'schtasks.exe',
        ['/Query', '/TN', taskName],
      );
      return result.exitCode == 0;
    }

    if (Platform.isMacOS) {
      return File(_macOSLaunchAgentPath()).exists();
    }

    return false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (Platform.isWindows) {
      if (enabled) {
        await _createOrUpdateTask();
      } else {
        await _deleteTaskIfExists();
      }
      return;
    }

    if (Platform.isMacOS) {
      if (enabled) {
        await _createOrUpdateLaunchAgent();
      } else {
        await _deleteLaunchAgentIfExists();
      }
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

  Future<void> _createOrUpdateLaunchAgent() async {
    final file = File(_macOSLaunchAgentPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(_launchAgentPlist(), flush: true);
    final guiDomain = await _macOSGuiDomain();
    await _launchCtl(
      'bootstrap',
      [guiDomain, file.path],
      ignoreFailures: true,
    );
  }

  Future<void> _deleteLaunchAgentIfExists() async {
    final file = File(_macOSLaunchAgentPath());
    if (!await file.exists()) {
      return;
    }

    final guiDomain = await _macOSGuiDomain();
    await _launchCtl(
      'bootout',
      [guiDomain, file.path],
      ignoreFailures: true,
    );
    await file.delete();
  }

  String _macOSLaunchAgentPath() {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    return p.join(
      home,
      'Library',
      'LaunchAgents',
      '$macOSLaunchAgentLabel.plist',
    );
  }

  static String get macOSLaunchAgentLabel {
    final normalized = _buildVariant.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'prod') {
      return 'com.mayday.app';
    }
    final suffix = normalized.replaceAll(RegExp(r'[^a-z0-9_.-]'), '-');
    return 'com.mayday.$suffix.app';
  }

  String _launchAgentPlist() {
    final executable = _xmlEscape(Platform.resolvedExecutable);
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$macOSLaunchAgentLabel</string>
  <key>ProgramArguments</key>
  <array>
    <string>$executable</string>
    <string>--autostart</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Future<String> _macOSGuiDomain() async {
    final result = await Process.run('id', ['-u']);
    if (result.exitCode != 0) {
      return 'gui/${Platform.environment['UID'] ?? ''}';
    }
    return 'gui/${result.stdout.toString().trim()}';
  }

  Future<void> _launchCtl(
    String command,
    List<String> arguments, {
    required bool ignoreFailures,
  }) async {
    final result = await Process.run('launchctl', [command, ...arguments]);
    if (ignoreFailures || result.exitCode == 0) {
      return;
    }

    throw ProcessException(
      'launchctl',
      [command, ...arguments],
      _processOutput(result),
      result.exitCode,
    );
  }

  String _processOutput(ProcessResult result) {
    return [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
    ].where((line) => line.isNotEmpty).join('\n');
  }
}

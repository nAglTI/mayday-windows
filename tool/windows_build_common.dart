import 'dart:io';

import 'package:path/path.dart' as p;

String resolveRepoRoot() {
  final scriptPath = p.fromUri(Platform.script);
  return p.dirname(p.dirname(scriptPath));
}

String defaultFlutterCommand(String repoRoot) {
  final localFlutter = p.join(repoRoot, 'flutter', 'bin', 'flutter.bat');
  return File(localFlutter).existsSync() ? localFlutter : 'flutter';
}

String defaultBuildName(String repoRoot) {
  final pubspec = File(p.join(repoRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return '0.1.0';
  }

  final versionPattern = RegExp(r'^version:\s*([^\s+]+)', multiLine: true);
  final match = versionPattern.firstMatch(pubspec.readAsStringSync());
  return match?.group(1) ?? '0.1.0';
}

String defaultWindowsSymbolsDir(String repoRoot, String buildName) {
  return p.join(repoRoot, 'build', 'symbols', 'windows', buildName);
}

String optionValue(
  List<String> args,
  String name, {
  required String defaultValue,
}) {
  final inlinePrefix = '$name=';
  for (var index = 0; index < args.length; index += 1) {
    final value = args[index];
    if (value.startsWith(inlinePrefix)) {
      return value.substring(inlinePrefix.length);
    }
    if (value == name && index + 1 < args.length) {
      return args[index + 1];
    }
  }
  return defaultValue;
}

bool hasFlag(List<String> args, String name) => args.contains(name);

Future<void> runChecked(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Command failed with exit code $exitCode',
      exitCode,
    );
  }
}

String resolveIsccPath(String explicitPath) {
  if (explicitPath.isNotEmpty && File(explicitPath).existsSync()) {
    return explicitPath;
  }

  final candidates = [
    r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    r'C:\Program Files\Inno Setup 6\ISCC.exe',
    if (Platform.environment['LOCALAPPDATA'] case final localAppData?)
      p.join(localAppData, 'Programs', 'Inno Setup 6', 'ISCC.exe'),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  if (_findOnPath('ISCC.exe') case final path?) {
    return path;
  }

  throw StateError('ISCC.exe not found. Pass --iscc-path explicitly.');
}

String? _findOnPath(String executableName) {
  final pathValue = Platform.environment['PATH'];
  if (pathValue == null || pathValue.trim().isEmpty) {
    return null;
  }

  for (final directory in pathValue.split(';')) {
    if (directory.trim().isEmpty) {
      continue;
    }
    final candidate = p.join(directory, executableName);
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

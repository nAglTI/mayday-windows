import 'dart:io';

import 'package:path/path.dart' as p;

class AppBuildVersion {
  const AppBuildVersion({
    required this.buildName,
    required this.buildNumber,
  });

  factory AppBuildVersion.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    final parts = trimmed.split('+');
    return AppBuildVersion(
      buildName: _normalizeBuildName(parts.first),
      buildNumber: parts.length > 1 ? _normalizeBuildNumber(parts[1]) : '0',
    );
  }

  factory AppBuildVersion.fromParts({
    required String buildName,
    required String buildNumber,
  }) {
    final parsedName = AppBuildVersion.parse(buildName);
    final parsedNumber = buildNumber.trim().isEmpty
        ? parsedName.buildNumber
        : _normalizeBuildNumber(buildNumber);
    return AppBuildVersion(
      buildName: parsedName.buildName,
      buildNumber: parsedNumber,
    );
  }

  static const fallback = AppBuildVersion(
    buildName: '0.1.0',
    buildNumber: '0',
  );

  final String buildName;
  final String buildNumber;

  String get displayVersion {
    return buildNumber == '0' ? buildName : '$buildName+$buildNumber';
  }

  String get windowsVersion {
    final components = buildName.split('.').map(int.parse).toList();
    while (components.length < 3) {
      components.add(0);
    }
    return '${components[0]}.${components[1]}.${components[2]}.$buildNumber';
  }

  static String _normalizeBuildName(String value) {
    final trimmed = value.trim();
    final pattern = RegExp(r'^\d+(?:\.\d+){0,2}$');
    if (!pattern.hasMatch(trimmed)) {
      throw FormatException(
        'App version must be numeric x.y.z, got "$value".',
      );
    }

    final parts = trimmed.split('.');
    for (final part in parts) {
      _parseWindowsVersionComponent(part, 'App version component');
    }
    while (parts.length < 3) {
      parts.add('0');
    }
    return parts.join('.');
  }

  static String _normalizeBuildNumber(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      throw FormatException(
        'App build number must be numeric, got "$value".',
      );
    }
    return '${_parseWindowsVersionComponent(trimmed, 'App build number')}';
  }

  static int _parseWindowsVersionComponent(String value, String label) {
    final parsed = int.parse(value);
    if (parsed > 65535) {
      throw FormatException(
        '$label must be between 0 and 65535 for Windows resources, '
        'got "$value".',
      );
    }
    return parsed;
  }
}

String resolveRepoRoot() {
  final scriptPath = p.fromUri(Platform.script);
  return p.dirname(p.dirname(scriptPath));
}

String defaultFlutterCommand(String repoRoot) {
  final localFlutter = p.join(repoRoot, 'flutter', 'bin', 'flutter.bat');
  return File(localFlutter).existsSync() ? localFlutter : 'flutter';
}

String defaultBuildName(String repoRoot) {
  return defaultBuildVersion(repoRoot).buildName;
}

String defaultBuildNumber(String repoRoot) {
  return defaultBuildVersion(repoRoot).buildNumber;
}

AppBuildVersion defaultBuildVersion(String repoRoot) {
  final pubspec = File(p.join(repoRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return AppBuildVersion.fallback;
  }

  final versionPattern = RegExp(r'^version:\s*([^\s#]+)', multiLine: true);
  final match = versionPattern.firstMatch(pubspec.readAsStringSync());
  final value = match?.group(1);
  return value == null
      ? AppBuildVersion.fallback
      : AppBuildVersion.parse(value);
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
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
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

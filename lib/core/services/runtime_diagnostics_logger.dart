import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/runtime_paths.dart';

class RuntimeDiagnosticsLogger {
  const RuntimeDiagnosticsLogger({
    this.enabled = !kReleaseMode,
  });

  final bool enabled;

  Future<String> getLogPath(RuntimePaths paths) async {
    if (!enabled) {
      return '';
    }

    final logsDir = p.join(paths.mutableRoot, 'logs');
    await Directory(logsDir).create(recursive: true);
    return p.join(logsDir, 'mayday-launch.log');
  }

  Future<void> writeEvent(
    RuntimePaths paths, {
    required String event,
    Map<String, Object?> fields = const {},
  }) async {
    if (!enabled) {
      return;
    }

    final logPath = await getLogPath(paths);
    final buffer = StringBuffer()..writeln('[$_now] $event');

    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.writeln('${entry.key}: $value');
    }

    buffer.writeln();
    await File(logPath).writeAsString(
      buffer.toString(),
      mode: FileMode.append,
      flush: true,
    );
  }

  String configPreview(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .take(40)
        .map(_redactConfigLine)
        .join('\n')
        .trim();

    const maxLength = 2000;
    if (lines.length <= maxLength) {
      return lines;
    }
    return '${lines.substring(0, maxLength)}\n...';
  }

  String get _now => DateTime.now().toIso8601String();

  String _redactConfigLine(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('key:') ||
        trimmed.startsWith('user_id:') ||
        trimmed.startsWith('addr:') ||
        trimmed.startsWith('ports:') ||
        trimmed.startsWith('- key:') ||
        trimmed.startsWith('- addr:') ||
        trimmed.startsWith('- ports:')) {
      final indentLength = line.length - trimmed.length;
      return '${' ' * indentLength}${trimmed.split(':').first}: <redacted>';
    }
    return line;
  }
}

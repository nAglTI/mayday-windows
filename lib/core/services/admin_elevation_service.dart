import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../l10n/app_texts.dart';

class RelaunchResult {
  const RelaunchResult({
    required this.started,
    this.message,
  });

  final bool started;
  final String? message;
}

class AdminBootstrapResult {
  const AdminBootstrapResult({
    required this.isElevated,
    this.exitRequested = false,
    this.message,
  });

  final bool isElevated;
  final bool exitRequested;
  final String? message;
}

class AdminElevationService {
  const AdminElevationService({
    AppTextCatalog? textCatalog,
  }) : _textCatalog = textCatalog ?? const AppTextCatalog(AppLanguage.english);

  final AppTextCatalog _textCatalog;

  Future<AdminBootstrapResult> bootstrap() async {
    final isElevated = await isRunningAsAdministrator();
    if (isElevated) {
      return const AdminBootstrapResult(isElevated: true);
    }

    final relaunchResult = await restartAsAdministrator();
    if (relaunchResult.started) {
      return const AdminBootstrapResult(
        isElevated: false,
        exitRequested: true,
      );
    }

    return AdminBootstrapResult(
      isElevated: false,
      message: relaunchResult.message ?? _textCatalog.t('error.admin_required'),
    );
  }

  Future<bool> isRunningAsAdministrator() async {
    return using((arena) {
      final tokenHandle = arena<Pointer>();
      final opened = OpenProcessToken(
        GetCurrentProcess(),
        TOKEN_QUERY,
        tokenHandle,
      );
      if (!opened.value) {
        return false;
      }

      final token = HANDLE(tokenHandle.value);
      try {
        final elevation = arena<TOKEN_ELEVATION>();
        final returnLength = arena<Uint32>();
        final read = GetTokenInformation(
          token,
          TokenElevation,
          elevation,
          sizeOf<TOKEN_ELEVATION>(),
          returnLength,
        );
        return read.value && elevation.ref.TokenIsElevated != 0;
      } finally {
        token.close();
      }
    });
  }

  Future<RelaunchResult> restartAsAdministrator() async {
    try {
      final started = _shellExecuteRunAs(
        executable: Platform.resolvedExecutable,
        arguments: Platform.executableArguments,
        workingDirectory: Directory.current.path,
      );
      return started
          ? const RelaunchResult(started: true)
          : RelaunchResult(
              started: false,
              message: _textCatalog.t('admin.relaunch_cancelled_or_failed'),
            );
    } catch (error) {
      return RelaunchResult(
        started: false,
        message: _textCatalog.t('admin.restart_failed', {'error': error}),
      );
    }
  }

  bool _shellExecuteRunAs({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) {
    return using((arena) {
      final info = arena<SHELLEXECUTEINFO>();
      final verb = 'runas'.toNativeUtf16(allocator: arena);
      final file = executable.toNativeUtf16(allocator: arena);
      final directory = workingDirectory.toNativeUtf16(allocator: arena);
      final params = arguments
          .map(_quoteCommandLineArgument)
          .join(' ')
          .toNativeUtf16(allocator: arena);

      info.ref
        ..cbSize = sizeOf<SHELLEXECUTEINFO>()
        ..lpVerb = PWSTR(verb)
        ..lpFile = PWSTR(file)
        ..lpParameters = PWSTR(params)
        ..lpDirectory = PWSTR(directory)
        ..nShow = SW_NORMAL;

      final result = ShellExecuteEx(info);
      return result.value;
    });
  }

  String _quoteCommandLineArgument(String value) {
    if (value.isEmpty) {
      return '""';
    }
    if (!RegExp(r'[\s"]').hasMatch(value)) {
      return value;
    }

    final buffer = StringBuffer('"');
    var backslashes = 0;
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == r'\') {
        backslashes += 1;
        continue;
      }
      if (char == '"') {
        buffer
          ..write(_repeatBackslash(backslashes * 2 + 1))
          ..write(char);
        backslashes = 0;
        continue;
      }
      if (backslashes > 0) {
        buffer.write(_repeatBackslash(backslashes));
        backslashes = 0;
      }
      buffer.write(char);
    }
    buffer
      ..write(_repeatBackslash(backslashes * 2))
      ..write('"');
    return buffer.toString();
  }

  String _repeatBackslash(int count) {
    return List.filled(count, r'\').join();
  }
}

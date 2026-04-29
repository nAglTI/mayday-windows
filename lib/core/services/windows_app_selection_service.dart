import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../l10n/app_texts.dart';
import '../models/running_windows_app.dart';

class WindowsAppSelectionService {
  WindowsAppSelectionService({AppTextCatalog? textCatalog})
      : _textCatalog = textCatalog ?? const AppTextCatalog(AppLanguage.english);

  final AppTextCatalog _textCatalog;

  Future<String?> pickExecutablePath() async {
    return _showOpenFileDialog(
      title: _textCatalog.t('button.choose_exe'),
      filterPairs: [
        _textCatalog.t('label.executable_filter'),
        _textCatalog.t('label.exe_files_filter'),
        ..._textCatalog.t('label.all_files_filter').split('|'),
      ],
    );
  }

  Future<List<RunningWindowsApp>> listRunningApps() async {const maxProcesses = 32768;
    final apps = <RunningWindowsApp>[];
    final seen = <String>{};

    using((arena) {
      final processIds = arena<Uint32>(maxProcesses);
      final bytesNeeded = arena<Uint32>();
      final enumerated = EnumProcesses(
        processIds,
        maxProcesses * sizeOf<Uint32>(),
        bytesNeeded,
      );
      if (!enumerated.value) {
        throw WindowsException(enumerated.error.toHRESULT());
      }

      final processCount = bytesNeeded.value ~/ sizeOf<Uint32>();
      for (var index = 0; index < processCount; index += 1) {
        final processId = processIds[index];
        if (processId == 0) {
          continue;
        }

        final path = _queryProcessPath(processId);
        if (path == null || path.isEmpty || !seen.add(path.toLowerCase())) {
          continue;
        }

        apps.add(
          RunningWindowsApp(
            name: _fallbackName(path),
            path: path,
          ),
        );
      }
    });

    apps.sort((left, right) => left.name.compareTo(right.name));
    return apps;
  }

  String? _queryProcessPath(int processId) {
    return using((arena) {
      final process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        false,
        processId,
      ).value;
      if (!process.isValid) {
        return null;
      }

      try {
        const maxPathChars = 32768;
        final buffer = arena<Uint16>(maxPathChars).cast<Utf16>();
        final length = arena<Uint32>()..value = maxPathChars;
        final queried = QueryFullProcessImageName(
          process,
          PROCESS_NAME_WIN32,
          PWSTR(buffer),
          length,
        );
        if (!queried.value || length.value == 0) {
          return null;
        }
        return PWSTR(buffer).toDartString(length: length.value);
      } finally {
        process.close();
      }
    });
  }

  String? _showOpenFileDialog({
    required String title,
    required List<String> filterPairs,
  }) {
    const maxFileChars = 32768;

    return using((arena) {
      final fileName = arena<Uint16>(maxFileChars).cast<Utf16>();
      final filter = _nativeFilter(filterPairs).toNativeUtf16(
        allocator: arena,
      );
      final nativeTitle = title.toNativeUtf16(allocator: arena);
      final ofn = arena<OPENFILENAME>();

      ofn.ref
        ..lStructSize = sizeOf<OPENFILENAME>()
        ..lpstrFile = PWSTR(fileName)
        ..nMaxFile = maxFileChars
        ..lpstrFilter = PWSTR(filter)
        ..lpstrTitle = PWSTR(nativeTitle)
        ..Flags = OPEN_FILENAME_FLAGS(
          OFN_EXPLORER |
              OFN_FILEMUSTEXIST |
              OFN_PATHMUSTEXIST |
              OFN_NOCHANGEDIR |
              OFN_HIDEREADONLY,
        );

      if (!GetOpenFileName(ofn)) {
        return null;
      }

      final selectedPath = PWSTR(fileName).toDartString();
      return selectedPath.trim().isEmpty ? null : selectedPath;
    });
  }

  String _nativeFilter(List<String> pairs) {
    final normalized = [
      for (final value in pairs)
        if (value.trim().isNotEmpty) value.trim(),
    ];
    return '${normalized.join('\x00')}\x00\x00';
  }

  String _fallbackName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }
}

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../l10n/app_texts.dart';

class ConfigFilePickerService {
  ConfigFilePickerService({AppTextCatalog? textCatalog})
      : _textCatalog = textCatalog ?? const AppTextCatalog(AppLanguage.english);

  final AppTextCatalog _textCatalog;

  Future<String?> pickConfigPath() async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        _textCatalog.t('error.config_picker_unsupported'),
      );
    }

    return _showOpenFileDialog(
      title: _textCatalog.t('button.import_config'),
      filterPairs: [
        _textCatalog.t('label.config_filter'),
        _textCatalog.t('label.config_files_filter'),
        ..._textCatalog.t('label.all_files_filter').split('|'),
      ],
    );
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
}

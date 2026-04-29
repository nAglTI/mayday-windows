import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/client_profile.dart';
import '../models/runtime_paths.dart';
import '../l10n/app_texts.dart';
import 'runtime_paths_service.dart';
import 'runtime_diagnostics_logger.dart';
import 'client_profile_codec.dart';
import 'profile_encryption_service.dart';

class ClientProfileStorage {
  ClientProfileStorage({
    RuntimePathsService? runtimePathsService,
    ClientProfileCodec? codec,
    AppTextCatalog? textCatalog,
    RuntimeDiagnosticsLogger? diagnosticsLogger,
    ProfileEncryptionService? encryptionService,
  })  : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService(),
        _textCatalog = textCatalog ?? const AppTextCatalog(AppLanguage.english),
        _codec = codec ??
            ClientProfileCodec(
                appTextCatalog:
                    textCatalog ?? const AppTextCatalog(AppLanguage.english)),
        _diagnosticsLogger =
            diagnosticsLogger ?? const RuntimeDiagnosticsLogger(),
        _encryptionService =
            encryptionService ?? const ProfileEncryptionService();

  final RuntimePathsService _runtimePathsService;
  final AppTextCatalog _textCatalog;
  final ClientProfileCodec _codec;
  final RuntimeDiagnosticsLogger _diagnosticsLogger;
  final ProfileEncryptionService _encryptionService;

  Future<RuntimePaths> getPaths() {
    return _runtimePathsService.getPaths();
  }

  Future<ClientProfile?> loadSavedProfile() async {
    final raw = await loadSavedRawConfig();
    if (raw == null) {
      return null;
    }

    return _codec.parseRaw(
      raw,
      currentProfileName: _textCatalog.t('file.saved_name'),
    );
  }

  Future<String?> loadSavedRawConfig() async {
    final paths = await _runtimePathsService.getPaths();
    final encryptedFile = File(paths.configPath);
    final legacyFile = File(_legacyPlainConfigPath(paths));

    if (await encryptedFile.exists()) {
      final encrypted = await encryptedFile.readAsString();
      final raw = await _encryptionService.decrypt(encrypted);
      await _deleteIfExists(legacyFile);
      return raw;
    }

    if (await legacyFile.exists()) {
      final raw = await legacyFile.readAsString();
      await _writeEncrypted(paths, raw);
      await _deleteIfExists(legacyFile);
      return raw;
    }

    return null;
  }

  Future<File> saveProfile(ClientProfile profile) async {
    final paths = await _runtimePathsService.getPaths();
    await _runtimePathsService.ensureMutableDirectories(paths);
    final encoded = _codec.encodeYaml(profile);

    if (_diagnosticsLogger.enabled) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'config.save.started',
        fields: {
          'configPath': paths.configPath,
          'encryptedAtRest': true,
          'encodedBytes': utf8.encode(encoded).length,
          'preview': '\n${_diagnosticsLogger.configPreview(encoded)}',
        },
      );
    }

    try {
      final savedFile = await _writeEncrypted(paths, encoded);
      await _deleteIfExists(File(_legacyPlainConfigPath(paths)));
      if (!_diagnosticsLogger.enabled) {
        return savedFile;
      }

      final stat = await savedFile.stat();
      final readBack = await _encryptionService.decrypt(
        await savedFile.readAsString(),
      );

      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'config.save.completed',
        fields: {
          'configPath': savedFile.path,
          'encryptedAtRest': true,
          'exists': await savedFile.exists(),
          'sizeBytes': stat.size,
          'modified': stat.modified.toIso8601String(),
          'readBackOk': readBack == encoded,
          'readBackBytes': utf8.encode(readBack).length,
          'preview': '\n${_diagnosticsLogger.configPreview(readBack)}',
        },
      );

      return savedFile;
    } catch (error) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'config.save.failed',
        fields: {
          'configPath': paths.configPath,
          'error': error,
        },
      );
      rethrow;
    }
  }

  Future<File> writeRuntimeConfig(ClientProfile profile) async {
    final paths = await _runtimePathsService.getPaths();
    await _runtimePathsService.ensureMutableDirectories(paths);
    final encoded = _codec.encodeYaml(profile);
    final file = File(_runtimeConfigPath(paths));
    return file.writeAsString(encoded, flush: true);
  }

  Future<File> _writeEncrypted(RuntimePaths paths, String rawConfig) async {
    final encrypted = await _encryptionService.encrypt(rawConfig);
    final file = File(paths.configPath);
    return file.writeAsString(encrypted, flush: true);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _legacyPlainConfigPath(RuntimePaths paths) {
    return p.join(paths.configDir, 'client.yaml');
  }

  String _runtimeConfigPath(RuntimePaths paths) {
    return p.join(paths.configDir, 'client.runtime.yaml');
  }
}

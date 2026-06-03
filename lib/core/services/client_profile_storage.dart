import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_metadata.dart';
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
        _codec = codec ??
            ClientProfileCodec(
                appTextCatalog:
                    textCatalog ?? const AppTextCatalog(AppLanguage.english)),
        _diagnosticsLogger =
            diagnosticsLogger ?? const RuntimeDiagnosticsLogger(),
        _encryptionService =
            encryptionService ?? const ProfileEncryptionService();

  final RuntimePathsService _runtimePathsService;
  final ClientProfileCodec _codec;
  final RuntimeDiagnosticsLogger _diagnosticsLogger;
  final ProfileEncryptionService _encryptionService;

  static const currentContractVersion = 5;
  static const _metadataFileName = 'client_profile_metadata.json';

  Future<RuntimePaths> getPaths() {
    return _runtimePathsService.getPaths();
  }

  Future<ClientProfile?> loadSavedProfile() async {
    final raw = await loadSavedRawConfig();
    if (raw == null) {
      return null;
    }

    return _codec.parseRaw(raw);
  }

  Future<ClientProfile?> loadSavedProfileForCurrentContract() async {
    final paths = await _runtimePathsService.getPaths();
    final raw = await loadSavedRawConfig();
    if (raw == null) {
      return null;
    }

    final metadata = await _readMetadata(paths);
    if (metadata == null) {
      final profile = _codec.parseCurrentContractRaw(raw);
      await _writeMetadata(paths);
      return profile;
    }

    final contractVersion = _readInt(metadata['contractVersion']);
    if (contractVersion != currentContractVersion) {
      throw ClientProfileContractException(
        'Saved profile contract $contractVersion is not supported.',
      );
    }

    return _codec.parseCurrentContractRaw(raw);
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
      await _writeMetadata(paths);
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

  Future<Map<String, Object?>?> _readMetadata(RuntimePaths paths) async {
    try {
      final file = File(_metadataPath(paths));
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      // Treat malformed metadata as missing and validate the raw profile.
    }

    return null;
  }

  Future<File> _writeMetadata(RuntimePaths paths) async {
    await _runtimePathsService.ensureMutableDirectories(paths);
    final file = File(_metadataPath(paths));
    final metadata = {
      'contractVersion': currentContractVersion,
      'appVersion': MaydayAppMetadata.version,
      'savedAt': DateTime.now().toIso8601String(),
    };
    return file.writeAsString(jsonEncode(metadata), flush: true);
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString().trim() ?? '');
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

  String _metadataPath(RuntimePaths paths) {
    return p.join(paths.configDir, _metadataFileName);
  }
}

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class ProfileEncryptionService {
  const ProfileEncryptionService();

  static const String _buildVariant = String.fromEnvironment(
    'MAYDAY_BUILD_VARIANT',
    defaultValue: 'local',
  );

  Future<String> encrypt(String plainText) async {
    if (Platform.isWindows) {
      return _protectWithWindowsDpapi(utf8.encode(plainText));
    }
    if (Platform.isMacOS) {
      return _protectWithMacOSKeychain(plainText);
    }
    return 'base64-v1:${base64Encode(utf8.encode(plainText))}';
  }

  Future<String> decrypt(String encryptedText) async {
    if (encryptedText.startsWith('keychain-v1:')) {
      return _unprotectWithMacOSKeychain(encryptedText);
    }
    if (encryptedText.startsWith('base64-v1:')) {
      return utf8.decode(
        base64Decode(encryptedText.substring('base64-v1:'.length)),
      );
    }
    if (Platform.isWindows) {
      return utf8
          .decode(_unprotectWithWindowsDpapi(base64Decode(encryptedText)));
    }
    throw UnsupportedError(
      'Saved profile encryption format is not supported on this platform.',
    );
  }

  String _protectWithWindowsDpapi(List<int> bytes) {
    return using((arena) {
      final dataIn = arena<CRYPT_INTEGER_BLOB>();
      final dataOut = arena<CRYPT_INTEGER_BLOB>();
      final input = arena<Uint8>(bytes.length);
      input.asTypedList(bytes.length).setAll(0, bytes);

      dataIn.ref
        ..cbData = bytes.length
        ..pbData = input;

      final result = CryptProtectData(dataIn, null, null, null, 0, dataOut);
      if (!result.value) {
        throw WindowsException(result.error.toHRESULT());
      }

      try {
        return base64Encode(
          dataOut.ref.pbData.asTypedList(dataOut.ref.cbData),
        );
      } finally {
        HLOCAL(dataOut.ref.pbData.cast()).close();
      }
    });
  }

  List<int> _unprotectWithWindowsDpapi(List<int> bytes) {
    return using((arena) {
      final dataIn = arena<CRYPT_INTEGER_BLOB>();
      final dataOut = arena<CRYPT_INTEGER_BLOB>();
      final input = arena<Uint8>(bytes.length);
      input.asTypedList(bytes.length).setAll(0, bytes);

      dataIn.ref
        ..cbData = bytes.length
        ..pbData = input;

      final result = CryptUnprotectData(dataIn, null, null, null, 0, dataOut);
      if (!result.value) {
        throw WindowsException(result.error.toHRESULT());
      }

      try {
        return List<int>.from(
          dataOut.ref.pbData.asTypedList(dataOut.ref.cbData),
        );
      } finally {
        HLOCAL(dataOut.ref.pbData.cast()).close();
      }
    });
  }

  Future<String> _protectWithMacOSKeychain(String plainText) async {
    final service = _macOSKeychainServiceName;
    const account = 'client-profile';
    final result = await Process.run('/usr/bin/security', [
      'add-generic-password',
      '-a',
      account,
      '-s',
      service,
      '-w',
      plainText,
      '-U',
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        '/usr/bin/security',
        const ['add-generic-password'],
        _processOutput(result),
        result.exitCode,
      );
    }

    return [
      'keychain-v1',
      _base64UrlNoPadding(service),
      _base64UrlNoPadding(account),
    ].join(':');
  }

  Future<String> _unprotectWithMacOSKeychain(String token) async {
    final parts = token.split(':');
    if (parts.length != 3) {
      throw const FormatException('Malformed macOS keychain profile token.');
    }

    final service = _decodeBase64UrlNoPadding(parts[1]);
    final account = _decodeBase64UrlNoPadding(parts[2]);
    final result = await Process.run('/usr/bin/security', [
      'find-generic-password',
      '-a',
      account,
      '-s',
      service,
      '-w',
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        '/usr/bin/security',
        const ['find-generic-password'],
        _processOutput(result),
        result.exitCode,
      );
    }

    return result.stdout.toString().replaceFirst(RegExp(r'\r?\n$'), '');
  }

  String get _macOSKeychainServiceName {
    final normalized = _buildVariant.trim().toLowerCase();
    final suffix = normalized.isEmpty || normalized == 'prod'
        ? 'prod'
        : normalized.replaceAll(RegExp(r'[^a-z0-9_.-]'), '-');
    return 'Mayday.$suffix.client-profile';
  }

  String _base64UrlNoPadding(String value) {
    return base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
  }

  String _decodeBase64UrlNoPadding(String value) {
    final padded =
        value.padRight(value.length + (4 - value.length % 4) % 4, '=');
    return utf8.decode(base64Url.decode(padded));
  }

  String _processOutput(ProcessResult result) {
    return [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
    ].where((value) => value.isNotEmpty).join('\n');
  }
}

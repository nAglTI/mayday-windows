import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class ProfileEncryptionService {
  const ProfileEncryptionService();

  Future<String> encrypt(String plainText) async {
    return _protect(utf8.encode(plainText));
  }

  Future<String> decrypt(String encryptedText) async {
    return utf8.decode(_unprotect(base64Decode(encryptedText)));
  }

  String _protect(List<int> bytes) {
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

  List<int> _unprotect(List<int> bytes) {
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
}

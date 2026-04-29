import 'dart:io';

import 'package:flutter/services.dart';

class TrayIconService {
  const TrayIconService({
    MethodChannel channel = const MethodChannel('mayday/tray'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> setVpnConnected(bool connected) async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setVpnConnected', connected);
    } on MissingPluginException {
      // Keeps widget tests and older runners from failing on a cosmetic update.
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects the device category using native Android platform signals.
/// Screen size alone must not classify tablets as televisions.
class DeviceLayout {
  DeviceLayout._();

  static const MethodChannel _channel =
      MethodChannel('com.streamia/device_identity');

  static bool isTelevision = false;

  static Future<void> initialize() async {
    isTelevision = false;

    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final result = await _channel
          .invokeMethod<bool>('isTelevision')
          .timeout(const Duration(seconds: 2));

      isTelevision = result ?? false;
    } on MissingPluginException {
      isTelevision = false;
    } on PlatformException {
      isTelevision = false;
    } on TimeoutException {
      isTelevision = false;
    }

    debugPrint(
      'Streamia device layout: '
      '${isTelevision ? "TV" : "Mobile"}',
    );
  }
}

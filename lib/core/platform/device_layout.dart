
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android platform signals determine the initial layout before runApp.
/// Screen width alone must not classify tablets as televisions.
class DeviceLayout {
  DeviceLayout._();

  static const MethodChannel _channel = MethodChannel('com.streamia/device_identity');
  static bool isTelevision = false;

  static Future<void> initialize() async {
    isTelevision = false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      isTelevision = await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      isTelevision = false;
    } on PlatformException {
      isTelevision = false;
    }
  }
}

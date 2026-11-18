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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      isTelevision = false;
      return;
    }

    // Keep the complete retry sequence within the bootstrap's 3s budget.
    // A successful native false is authoritative, not a detection failure.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _channel
            .invokeMethod<bool>('isTelevision')
            .timeout(const Duration(milliseconds: 750));

        if (result == null) {
          throw StateError('Native device layout returned no classification');
        }

        isTelevision = result;
        debugPrint('Streamia device layout: ${result ? "TV" : "Mobile"}');
        return;
      } on Exception catch (error) {
        lastError = error;
      } on StateError catch (error) {
        lastError = error;
      }

      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 100 * (attempt + 1)),
        );
      }
    }

    // Never launch the portrait onboarding on an unclassified Android device.
    // The existing bootstrap handles this error without opening the app.
    throw StateError('Streamia device layout detection failed: $lastError');
  }
}

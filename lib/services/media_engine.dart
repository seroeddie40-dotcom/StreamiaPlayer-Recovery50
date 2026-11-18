import 'package:media_kit/media_kit.dart';

class MediaEngine {
  MediaEngine._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static void ensureInitialized() {
    if (_initialized) return;

    MediaKit.ensureInitialized();

    _initialized = true;
  }

  static Player createPlayer() {
    ensureInitialized();
    return Player();
  }
}

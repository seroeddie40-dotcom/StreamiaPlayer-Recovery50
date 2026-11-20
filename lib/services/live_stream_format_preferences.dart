import 'package:shared_preferences/shared_preferences.dart';

import 'live_stream_format.dart';

/// Persists the preferred Xtream Live-TV stream format on this installation.
///
/// This setting does not change the format of movies, series or M3U sources.
/// The player must explicitly read the preference and use
/// [LiveStreamFormatResolver] when opening an Xtream Live-TV stream.
class LiveStreamFormatPreferences {
  const LiveStreamFormatPreferences._();

  static const String _tvKey = 'streamia_xtream_live_format_tv_v1';
  static const String _mobileKey = 'streamia_xtream_live_format_mobile_v1';

  static String _key({required bool isTv}) => isTv ? _tvKey : _mobileKey;

  static Future<LiveStreamFormat> load({required bool isTv}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(isTv: isTv));
    for (final format in LiveStreamFormat.values) {
      if (format.name == stored) return format;
    }
    return LiveStreamFormat.automatic;
  }

  static Future<bool> save(
    LiveStreamFormat format, {
    required bool isTv,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_key(isTv: isTv), format.name);
  }

  static Future<bool> reset({required bool isTv}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_key(isTv: isTv));
  }
}

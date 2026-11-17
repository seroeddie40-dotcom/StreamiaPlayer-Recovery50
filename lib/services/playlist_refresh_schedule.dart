import 'package:shared_preferences/shared_preferences.dart';

/// Local scheduling metadata; never contains playlist credentials.
class PlaylistRefreshSchedule {
  static const intervals = [0, 1, 3, 6, 12, 24];
  static const defaultHours = 6;
  static String _key(String source, String field) => 'playlist_refresh_v1:$source:$field';

  static Future<int> hours(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final value = prefs.getInt(_key(source, 'hours')) ?? defaultHours;
    return intervals.contains(value) ? value : defaultHours;
  }

  static Future<void> setHours(String source, int value) async {
    if (!intervals.contains(value)) throw ArgumentError.value(value);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_key(source, 'hours'), value)) {
      throw StateError('Refresh interval could not be saved');
    }
  }

  static bool isDue({required int hours, required DateTime now, DateTime? lastSuccess}) =>
      hours > 0 && (lastSuccess == null || !now.isBefore(lastSuccess.add(Duration(hours: hours))));

  // Repair only a legacy catalog with no usable category identifiers.
  // A partially categorized provider may intentionally omit some categories.
  static bool needsLegacyRepair(Iterable<String?> keys) {
    var hasItems = false;
    for (final key in keys) {
      hasItems = true;
      if (key != null && key.trim().isNotEmpty) return false;
    }
    return hasItems;
  }

  static Future<bool> repairAttempted(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_key(source, 'legacy_repair_v1')) ?? false;
  }

  static Future<void> markRepairAttempted(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(source, 'legacy_repair_v1'), true);
  }

  // Persist automatic attempt times across dashboard recreation and app restarts.
  static bool retryAllowed(DateTime now, DateTime? lastAttempt) =>
      lastAttempt == null || now.isBefore(lastAttempt) ||
      !now.isBefore(lastAttempt.add(const Duration(minutes: 15)));

  static Future<bool> automaticAttemptAllowed(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getInt(_key(source, 'automatic_attempt'));
    return retryAllowed(DateTime.now(), raw == null ? null :
        DateTime.fromMillisecondsSinceEpoch(raw));
  }

  static Future<void> markAutomaticAttempt(String source) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_key(source, 'automatic_attempt'),
        DateTime.now().millisecondsSinceEpoch)) {
      throw StateError('Automatic attempt could not be saved');
    }
  }

  static Future<bool> due(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getInt(_key(source, 'success'));
    return isDue(hours: await hours(source), now: DateTime.now(),
        lastSuccess: raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw));
  }

  static Future<void> markSuccess(String source) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_key(source, 'success'), DateTime.now().millisecondsSinceEpoch)) {
      throw StateError('Refresh success timestamp could not be saved');
    }
  }
}

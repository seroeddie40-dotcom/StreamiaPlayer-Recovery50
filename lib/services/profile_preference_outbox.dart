import 'profile_sync_clock.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Durable latest-intent queue. PIN tokens are never persisted.
class ProfilePreferenceOutbox {
  static Future<void> _tail = Future<void>.value();
  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }
  static String _prefix(String account, String profile) => 'profile_pref_pending_v1:$account:$profile:';
  static String _key(String account, String profile, String source, String area, String name) =>
      '${_prefix(account, profile)}${jsonEncode([source, area, name])}';

  static Future<void> enqueue(String account, String profile, String source, String area, String name, Object value) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(account, profile, source, area, name), jsonEncode({'value':value,'changed_at':ProfileSyncClock.now().toIso8601String()}))) {
      throw StateError('Could not persist pending preference');
    }
  });

  static Future<Map<String, dynamic>> _snapshot(String account, String profile) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefix(account, profile);
    return {for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) key.substring(prefix.length): jsonDecode(prefs.getString(key)!)};
  });

  static Future<Map<String,dynamic>> pending(String account,String profile) async => (await _snapshot(account,profile)).map((key, value) => MapEntry(key,value is Map ? value['value'] : value));

  static Future<void> flush(SupabaseClient client, String account, String profile, String? token, bool Function() current) async {
    final snapshot = await _snapshot(account, profile);
    for (final entry in snapshot.entries) {
      if (!current() || client.auth.currentUser?.id != account) return;
      final parts = jsonDecode(entry.key) as List;
      try {
        await client.rpc('write_profile_preference', params: {
          'p_profile_id': profile, 'p_parent_token': token,
          'p_source_key': parts[0], 'p_content_type': parts[1],
          'p_key': parts[2], 'p_value': entry.value is Map ? entry.value['value'] : entry.value,
          'p_changed_at': entry.value is Map ? entry.value['changed_at'] : '1970-01-01T00:00:00Z',
        });
      } catch (_) { return; }
      await _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final key = '${_prefix(account, profile)}${entry.key}';
        if (prefs.getString(key) == jsonEncode(entry.value)) await prefs.remove(key);
      });
    }
  }
}

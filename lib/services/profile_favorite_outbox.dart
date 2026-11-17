import 'profile_sync_clock.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Durable favorite intents; credentials and PIN session tokens are never stored.
class ProfileFavoriteOutbox {
  static Future<void> _tail = Future<void>.value();
  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }
  static String _prefix(String account, String profile) => 'favorite_pending_v1:$account:$profile:';
  static String _key(String account, String profile, String source, String type, String id) => '${_prefix(account, profile)}${jsonEncode([source,type,id])}';
  static Future<void> enqueue(String account, String profile, String source, String type, String id, String title, String label, bool present) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(account,profile,source,type,id), jsonEncode({'present':present,'title':title,'source_label':label,'changed_at':ProfileSyncClock.now().toIso8601String()}))) {
      throw StateError('Could not persist favorite');
    }
  });
  static Future<bool?> pendingValue(String account,String profile,String source,String type,String id) => _serial(() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(account,profile,source,type,id));
    return raw == null ? null : (jsonDecode(raw) as Map)['present'] as bool;
  });
  static String _cacheKey(String account, String profile) => 'favorite_cache_v1:$account:$profile';
  static String _identity(Map row) => jsonEncode([row['source_key'], row['content_type'], row['content_id'].toString()]);
  static Future<List<Map<String,dynamic>>> load(SupabaseClient client, String account, String profile, String? token, bool Function() current) async {
    if (!current() || client.auth.currentUser?.id != account) throw StateError('Profile changed');
    List<Map<String,dynamic>>? remote;
    try {
      final rows = <Map<String,dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final page = await client.rpc('read_profile_favorites', params: {'p_profile_id':profile,'p_parent_token':token}).eq('user_id',account).eq('family_profile_id',profile).order('id').range(offset,offset+499).timeout(const Duration(seconds: 8));
        rows.addAll(List<Map<String,dynamic>>.from(page));
        if (page.length < 500) break;
        if (!current()) throw StateError('Profile changed');
      }
      remote = rows;
    } catch (_) { /* Use the last successful snapshot. */ }
    return _serial(() async {
      if (!current() || client.auth.currentUser?.id != account) throw StateError('Profile changed');
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(account,profile);
      if (remote != null) await prefs.setString(key,jsonEncode(remote));
      final base = remote ?? List<Map<String,dynamic>>.from(jsonDecode(prefs.getString(key) ?? '[]'));
      final merged = {for (final row in base) _identity(row):row};
      final prefix = _prefix(account,profile);
      for (final k in prefs.getKeys().where((k)=>k.startsWith(prefix))) {
        final identity = k.substring(prefix.length);
        final parts = jsonDecode(identity) as List;
        final intent = jsonDecode(prefs.getString(k)!) as Map;
        if (intent['present'] == true) {
          merged[identity] = {'source_key':parts[0],'content_type':parts[1],'content_id':parts[2],'title':intent['title'],'source_label':intent['source_label']};
        } else { merged.remove(identity); }
      }
      return merged.values.toList();
    });
  }
  static bool _flushing = false;
  static Future<void> flush(SupabaseClient client,String account,String profile,String? token,bool Function() current) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefix = _prefix(account,profile);
      final snapshot = await _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        return {for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) key:prefs.getString(key)!};
      });
      for (final entry in snapshot.entries) {
        if (!current() || client.auth.currentUser?.id != account) return;
        final parts = jsonDecode(entry.key.substring(prefix.length)) as List;
        final row = jsonDecode(entry.value) as Map;
        final params = <String,dynamic>{'p_profile_id':profile,'p_parent_token':token};
        try {
          if (row['present'] == true) {
            await client.rpc('write_profile_favorites',params:{...params,'p_rows':[{'source_key':parts[0],'content_type':parts[1],'content_id':parts[2],'title':row['title'],'source_label':row['source_label'],'updated_at':row['changed_at'] ?? '1970-01-01T00:00:00Z'}]});
          } else {
            await client.rpc('remove_profile_favorite',params:{...params,'p_source_key':parts[0],'p_content_type':parts[1],'p_content_id':parts[2],'p_changed_at':row['changed_at'] ?? '1970-01-01T00:00:00Z'});
          }
        } catch (_) { return; }
        if (!current() || client.auth.currentUser?.id != account) return;
        await _serial(() async {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString(entry.key) == entry.value) await prefs.remove(entry.key);
        });
      }
      if (snapshot.isNotEmpty && current() && client.auth.currentUser?.id == account) {
        await load(client, account, profile, token, current);
      }
    } finally { _flushing = false; }
  }
}

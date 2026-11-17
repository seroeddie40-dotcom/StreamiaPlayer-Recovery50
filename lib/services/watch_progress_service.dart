import 'profile_sync_clock.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/family_session_provider.dart';

/// A service instance is bound to the account and profile at screen entry.
class WatchProgressService {
  final FamilySessionProvider family;
  final SupabaseClient _client;
  final String? _account;
  final String? _profile;
  static Future<void> _tail = Future<void>.value();
  WatchProgressService({required this.family, SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        _account = family.activeProfile?.accountUserId,
        _profile = family.activeProfile?.id;

  bool get isCurrent => _account != null && _profile != null && family.isReady &&
      _client.auth.currentUser?.id == _account && family.activeProfile?.id == _profile;
  String get _key => 'streamia_progress_v2:$_account:$_profile';
  Map<String, dynamic> get _auth => {'p_profile_id': _profile, 'p_parent_token': family.parentAccessToken};

  Future<T> _serial<T>(Future<T> Function() action) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try { return await action(); } finally { gate.complete(); }
  }

  Future<List<Map<String, dynamic>>> _local() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
  Future<void> _store(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(rows))) throw StateError('Progress storage failed');
  }
  bool _same(Map a, Map b) => a['source_key'] == b['source_key'] &&
      a['content_id'] == b['content_id'] && a['content_type'] == b['content_type'];
  DateTime _time(Map row) => DateTime.parse(row['watched_at'] as String);

  Future<void> _flush(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      if (!isCurrent) break;
      if (row['pending'] != true) continue;
      try {
        await _client.rpc('write_profile_watch_progress', params: {..._auth,
          'p_source_key': row['source_key'], 'p_content_id': row['content_id'],
          'p_content_type': row['content_type'], 'p_title': row['title'],
          'p_position': row['position_seconds'], 'p_duration': row['duration_seconds'],
          'p_watched_at': row['watched_at']});
        row['pending'] = false;
      } catch (_) { /* Retry on next flush. */ }
    }
    await _store(rows);
  }
  Future<void> flushPending() => _serial(() async {
    if (!isCurrent) return;
    await _flush(await _local());
  });

  Future<List<Map<String, dynamic>>> _load(String sourceKey) => _serial(() async {
    if (!isCurrent || sourceKey.isEmpty) return <Map<String, dynamic>>[];
    final rows = await _local();
    await _flush(rows);
    if (!isCurrent) return <Map<String, dynamic>>[];
    try {
      final result = await _client.rpc('read_profile_watch_progress', params: {..._auth, 'p_source_key': sourceKey});
      if (!isCurrent) return <Map<String, dynamic>>[];
      for (final raw in result as List) {
        final remote = Map<String, dynamic>.from(raw as Map);
        remote['pending'] = false;
        final index = rows.indexWhere((r) => _same(r, remote));
        if (index < 0) { rows.add(remote); }
        else if (!_time(rows[index]).isAfter(_time(remote))) { rows[index] = remote; }
      }
      await _store(rows);
    } catch (_) { /* Offline: keep cached progress. */ }
    if (!isCurrent) return <Map<String, dynamic>>[];
    return rows.where((r) => r['source_key'] == sourceKey).toList()
      ..sort((a,b) => _time(b).compareTo(_time(a)));
  });
  bool _unfinished(Map row) {
    final pos = (row['position_seconds'] as num?)?.toInt() ?? 0;
    final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
    return pos >= 5 && (duration <= 0 || pos < duration - 20);
  }
  Future<int?> loadPosition({required String sourceKey, required String contentId, required String contentType}) async {
    final rows = await _load(sourceKey);
    if (!isCurrent) return null;
    for (final row in rows) {
      if (row['content_id'] == contentId && row['content_type'] == contentType) {
        return _unfinished(row) ? (row['position_seconds'] as num).toInt() : null;
      }
    }
    return null;
  }
  Future<List<Map<String, dynamic>>> loadRecent({required String sourceKey, int limit = 20}) async {
    final rows = await _load(sourceKey);
    return isCurrent ? rows.where(_unfinished).take(limit).toList() : [];
  }
  Future<void> savePosition({required String sourceKey, required String contentId,
    required String contentType, required String title, required int positionSeconds,
    required int durationSeconds}) async {
    if (!isCurrent || sourceKey.isEmpty || contentId.isEmpty || positionSeconds < 0 ||
        !{'vod','series'}.contains(contentType)) return;
    final row = <String,dynamic>{'source_key': sourceKey, 'content_id': contentId,
      'content_type': contentType, 'title': title, 'position_seconds': positionSeconds,
      'duration_seconds': durationSeconds > 0 ? durationSeconds : null,
      'watched_at': ProfileSyncClock.now().toIso8601String(), 'pending': true};
    await _serial(() async {
      if (!isCurrent) return;
      final rows = await _local();
      if (!isCurrent) return;
      rows.removeWhere((r) => _same(r,row));
      rows.add(row);
      await _store(rows);
      await _flush(rows);
    });
  }
}

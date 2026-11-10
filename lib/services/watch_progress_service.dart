import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account-scoped playback progress. Stream URLs and playlist credentials are
/// deliberately never persisted; only stable content/source identifiers are.
class WatchProgressService {
  final SupabaseClient? _client;
  WatchProgressService({SupabaseClient? client})
      : _client = client ?? _tryClient();

  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  bool get _ready => _client?.auth.currentUser != null;
  Future<void> _queueOperations = Future<void>.value();

  Future<T> _serializeQueue<T>(Future<T> Function() action) async {
    final previous = _queueOperations;
    final gate = Completer<void>();
    _queueOperations = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  String? get _queueKey {
    final userId = _client?.auth.currentUser?.id;
    return userId == null ? null : 'streamia_watch_progress_queue_v1_$userId';
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final key = _queueKey;
    if (key == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> rows) async {
    final key = _queueKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(rows.take(100).toList()));
    } catch (_) {}
  }

  Future<void> _queueProgress(Map<String, dynamic> row) async {
    await _serializeQueue(() async {
      final rows = await _readQueue();
      rows.removeWhere((item) => item['source_key'] == row['source_key'] &&
          item['content_id'] == row['content_id'] && item['content_type'] == row['content_type']);
      rows.insert(0, row);
      await _writeQueue(rows.take(100).toList());
    });
  }

  /// Retries locally queued progress records for the currently signed-in user.
  Future<void> flushPending() async {
    if (!_ready || _queueKey == null) return;
    await _serializeQueue(() async {
      final accountId = _client!.auth.currentUser?.id;
      final rows = await _readQueue();
      if (rows.isEmpty) return;
      final remaining = <Map<String, dynamic>>[];
      for (final row in rows) {
        // Never replay a queued row after another account has signed in.
        if (row['user_id'] != accountId) continue;
        try {
          await _client!.from('watch_history').upsert(row,
              onConflict: 'user_id,source_key,content_id,content_type');
        } catch (_) {
          remaining.add(row);
        }
      }
      // Do not write an old account's queue into a newly signed-in account.
      if (_client!.auth.currentUser?.id == accountId) {
        await _writeQueue(remaining);
      }
    });
  }


  Future<int?> loadPosition({
    required String sourceKey,
    required String contentId,
    required String contentType,
  }) async {
    if (!_ready || sourceKey.isEmpty || contentId.isEmpty) return null;
    await flushPending();
    try {
      final row = await _client!
          .from('watch_history')
          .select('position_seconds,duration_seconds')
          .eq('source_key', sourceKey)
          .eq('content_id', contentId)
          .eq('content_type', contentType)
          .order('watched_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final position = (row['position_seconds'] as num?)?.toInt() ?? 0;
      final duration = (row['duration_seconds'] as num?)?.toInt();
      if (position <= 0 || (duration != null && duration > 0 && position >= duration - 20)) return null;
      return position;
    } catch (_) {
      // Progress sync must never prevent playback when offline or before migration.
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> loadRecent({required String sourceKey, int limit = 20}) async {
    if (!_ready || sourceKey.isEmpty) return const [];
    await flushPending();
    try {
      final rows = await _client!
          .from('watch_history')
          .select('content_id,content_type,title,position_seconds,duration_seconds,watched_at')
          .eq('source_key', sourceKey)
          .order('watched_at', ascending: false)
          .limit(limit);
      // Hide entries that are effectively completed; they remain stored so the
      // history can still be used for analytics or a future watch-history view.
      return List<Map<String, dynamic>>.from(rows).where((row) {
        final position = (row['position_seconds'] as num?)?.toInt() ?? 0;
        final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
        if (position < 5) return false;
        return duration <= 0 || position < duration - 20;
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePosition({
    required String sourceKey,
    required String contentId,
    required String contentType,
    required String title,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (!_ready || sourceKey.isEmpty || contentId.isEmpty || positionSeconds < 0) return;
    final row = <String, dynamic>{
      'user_id': _client!.auth.currentUser!.id,
      'source_key': sourceKey,
      'content_id': contentId,
      'content_type': contentType,
      'title': title,
      'position_seconds': positionSeconds,
      'duration_seconds': durationSeconds > 0 ? durationSeconds : null,
      'watched_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client!.from('watch_history').upsert(row,
          onConflict: 'user_id,source_key,content_id,content_type');
      await flushPending();
    } catch (_) {
      // Keep only the newest progress per source/content, scoped to this account.
      await _queueProgress(row);
    }
  }
}

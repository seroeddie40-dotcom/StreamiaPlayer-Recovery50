import 'profile_sync_clock.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/family_session_provider.dart';

/// Bound to the profile and playlist at player entry. Never mixes legacy history.
class ProfileHistoryService {
  final FamilySessionProvider family;
  final String source;
  final SupabaseClient client;
  final String? account, profile;
  static Future<void> _tail = Future<void>.value();
  ProfileHistoryService(this.family, this.source, {SupabaseClient? client})
      : client = client ?? Supabase.instance.client,
        account = family.activeProfile?.accountUserId,
        profile = family.activeProfile?.id;
  bool get isCurrent => account != null && profile != null && family.isReady &&
      client.auth.currentUser?.id == account && family.activeProfile?.id == profile;
  String get _key => 'streamia_history_v2:$account:$profile:$source';
  Map<String,dynamic> get _auth => {'p_profile_id':profile,'p_parent_token':family.parentAccessToken,'p_source_key':source};
  Future<T> _serial<T>(Future<T> Function() work) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try { return await work(); } finally { gate.complete(); }
  }
  List<Map<String,dynamic>> _rows(dynamic value) => (value as List? ?? []).map((r) => Map<String,dynamic>.from(r as Map)).toList();
  Future<Map<String,dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null ? {} : Map<String,dynamic>.from(jsonDecode(raw) as Map);
  }
  Future<void> _save(List<Map<String,dynamic>> cache,List<Map<String,dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key,jsonEncode({'cache':cache,'queue':queue}))) throw StateError('History storage failed');
  }
  Future<List<Map<String,dynamic>>> _sync({String? type,String? id,bool clear=false}) => _serial(() async {
    if (!isCurrent) return <Map<String,dynamic>>[];
    final state = await _load();
    var cache = _rows(state['cache']);
    final queue = _rows(state['queue']);
    if (!isCurrent) return <Map<String,dynamic>>[];
    if (type != null) {
      final event = <String,dynamic>{'content_type':type,'content_id':id,'viewed_at':ProfileSyncClock.now().toIso8601String(),'clear':clear};
      queue.add(event);
      _apply(cache,event);
      await _save(cache,queue);
    }
    try {
      while (queue.isNotEmpty && isCurrent) {
        final e = queue.first;
        if (e['clear'] == true) {
          await client.rpc('clear_profile_history',params:{..._auth,'p_content_type':e['content_type'],'p_cleared_at':e['viewed_at']});
        } else {
          await client.rpc('write_profile_history',params:{..._auth,'p_content_type':e['content_type'],'p_content_id':e['content_id'],'p_viewed_at':e['viewed_at']});
        }
        queue.removeAt(0);
        await _save(cache,queue);
      }
      if (!isCurrent) return <Map<String,dynamic>>[];
      final remote = await client.rpc('read_profile_history',params:_auth);
      if (!isCurrent) return <Map<String,dynamic>>[];
      cache = _rows(remote);
      await _save(cache,queue);
    } catch (_) { /* Pending events remain durable for retry. */ }
    return isCurrent ? cache : <Map<String,dynamic>>[];
  });
  void _apply(List<Map<String,dynamic>> rows,Map<String,dynamic> e) {
    rows.removeWhere((r) => r['content_type']==e['content_type'] && (e['clear']==true || r['content_id']==e['content_id']));
    if (e['clear'] != true) rows.add(e);
    rows.sort((a,b)=>DateTime.parse(b['viewed_at'] as String).compareTo(DateTime.parse(a['viewed_at'] as String)));
    final counts=<String,int>{};
    rows.removeWhere((r){final t=r['content_type'] as String; final n=(counts[t]??0)+1; counts[t]=n; return n>10;});
  }
  Future<List<Map<String,dynamic>>> refresh()=>_sync();
  Future<List<Map<String,dynamic>>> record(String type,String id)=>_sync(type:type,id:id);
  Future<List<Map<String,dynamic>>> clear(String type)=>_sync(type:type,clear:true);
}

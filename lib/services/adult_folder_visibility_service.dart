import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_profile.dart';
import 'profile_preference_outbox.dart';

/// Personal display preferences only; never reads or writes parental rules.
class AdultFolderVisibilityService {
  String _key(FamilyProfile profile) {
    if (!profile.isAdult) throw ArgumentError('Adult profile required');
    return 'adult_hidden_folders_v1:${profile.accountUserId}:${profile.id}';
  }

  Future<List<Map<String, dynamic>>> load(FamilyProfile profile, {String? parentToken}) async {
    final key = _key(profile);
    final prefs = await SharedPreferences.getInstance();
    if (parentToken != null) {
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser?.id == profile.accountUserId) {
          final rows = await client.rpc('read_adult_hidden_preferences', params: {
            'p_profile_id': profile.id, 'p_parent_token': parentToken,
          });
          if (client.auth.currentUser?.id != profile.accountUserId) return [];
          final merged = <Map<String, dynamic>>[...await load(profile)];
          for (final row in rows as List) {
            final category = (row['preference_key'] as String).substring(7);
            merged.removeWhere((r) => r['source_key'] == row['source_key'] && r['content_type'] == row['content_type'] && r['category_key'] == category);
            if (row['preference_value'] == true) merged.add({'source_key': row['source_key'], 'content_type': row['content_type'], 'category_key': category, 'is_visible': false});
          }
          final pending = await ProfilePreferenceOutbox.pending(profile.accountUserId, profile.id);
          for (final entry in pending.entries) {
            final parts = jsonDecode(entry.key) as List;
            final name = parts[2] as String;
            if (!name.startsWith('hidden:')) continue;
            final category = name.substring(7);
            merged.removeWhere((r) => r['source_key'] == parts[0] && r['content_type'] == parts[1] && r['category_key'] == category);
            if (entry.value == true) merged.add({'source_key': parts[0], 'content_type': parts[1], 'category_key': category, 'is_visible': false});
          }
          await prefs.setString(key, jsonEncode(merged));
          return merged;
        }
      } catch (_) { /* Retain local preferences if remote read fails. */ }
    }
    return _loadLocal(profile);
  }

  Future<List<Map<String, dynamic>>> _loadLocal(FamilyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profile));
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((entry) => Map<String, dynamic>.from(entry as Map)).toList();
  }

  Future<void> setVisibility({required FamilyProfile profile,
    required String sourceKey, required String contentType,
    required Iterable<String> categoryKeys, required bool visible, String? parentToken}) async {
    final key = _key(profile);
    final source = sourceKey.trim();
    final type = contentType.trim().toLowerCase();
    final categories = categoryKeys.map((e) => e.trim()).toSet();
    if (source.isEmpty || !{'live', 'vod', 'series'}.contains(type) || categories.contains('')) {
      throw ArgumentError('Invalid category identifiers');
    }
    final rules = await load(profile);
    rules.removeWhere((r) => r['source_key'] == source && r['content_type'] == type && categories.contains(r['category_key']));
    if (!visible) {
      rules.addAll(categories.map((category) => <String, dynamic>{
        'source_key': source, 'content_type': type, 'category_key': category, 'is_visible': false,
      }));
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(rules))) {
      throw StateError('Could not save folder preferences');
    }
    for (final category in categories) {
      await ProfilePreferenceOutbox.enqueue(profile.accountUserId, profile.id, source, type, 'hidden:$category', !visible);
    }
    if (parentToken != null) {
      final client = Supabase.instance.client;
      await ProfilePreferenceOutbox.flush(client, profile.accountUserId, profile.id, parentToken,
        () => client.auth.currentUser?.id == profile.accountUserId);
    }
  }
}

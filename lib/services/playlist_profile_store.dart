import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_profile.dart';

/// Stores playlist presentation metadata only. Playlist URLs and Xtream
/// credentials are deliberately not persisted by this service.
class PlaylistProfileStore {
  static const _storageKey = 'streamia_playlist_profiles_v1';
  // Serialize all profile writes, even when callers use different store instances.
  static Future<void> _writeTail = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<PlaylistProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final profiles = <PlaylistProfile>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic> && (item['sourceKey'] is String)) {
          profiles.add(PlaylistProfile.fromJson(item));
        }
      }
      profiles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return profiles;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAllUnlocked(List<PlaylistProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_storageKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    if (!ok) throw StateError('Playlist-Profile konnten nicht gespeichert werden.');
  }

  Future<void> saveAll(List<PlaylistProfile> profiles) =>
      _serialized(() => _saveAllUnlocked(List<PlaylistProfile>.of(profiles)));

  Future<void> setActive(String sourceKey) => _serialized(() async {
    final profiles = await load();
    if (!profiles.any((p) => p.sourceKey == sourceKey)) return;
    await _saveAllUnlocked([
      for (final profile in profiles) profile.copyWith(isActive: profile.sourceKey == sourceKey),
    ]);
  });

  Future<void> upsert(PlaylistProfile profile) => _serialized(() async {
    final profiles = await load();
    final index = profiles.indexWhere((p) => p.sourceKey == profile.sourceKey);
    if (index >= 0) {
      final previous = profiles[index];
      profiles[index] = profile.copyWith(
        folderName: previous.folderName,
        isVisible: previous.isVisible,
        sortOrder: previous.sortOrder,
        isActive: true,
      );
    } else {
      profiles.add(profile.copyWith(sortOrder: profiles.length, isActive: true));
    }
    final active = profiles.indexWhere((p) => p.sourceKey == profile.sourceKey);
    for (var i = 0; i < profiles.length; i++) {
      profiles[i] = profiles[i].copyWith(isActive: i == active);
    }
    await _saveAllUnlocked(profiles);
  });
}

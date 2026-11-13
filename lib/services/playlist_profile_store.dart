
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist_profile.dart';

/// Stores playlist presentation metadata only.
///
/// Playlist URLs and Xtream credentials are deliberately
/// stored separately in PlaylistSourceStore.
///
/// During a trial, at most one distinct playlist profile
/// may be stored. Existing profiles can still be updated.
class PlaylistProfileStore {
  static const _storageKey = 'streamia_playlist_profiles_v1';

  // Serialize profile writes across all store instances.
  static Future<void> _writeTail = Future<void>.value();

  static Future<T> _serialized<T>(
    Future<T> Function() operation,
  ) {
    final result = _writeTail.then((_) => operation());

    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );

    return result;
  }

  Future<List<PlaylistProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      final profiles = <PlaylistProfile>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic> &&
            item['sourceKey'] is String) {
          profiles.add(
            PlaylistProfile.fromJson(item),
          );
        }
      }

      profiles.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      return profiles;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAllUnlocked(
    List<PlaylistProfile> profiles,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );

    final saved = await prefs.setString(
      _storageKey,
      encoded,
    );

    if (!saved) {
      throw StateError(
        'Playlist-Profile konnten nicht gespeichert werden.',
      );
    }
  }

  /// Saves all profiles.
  ///
  /// Callers must enforce the appropriate account limit
  /// before using this unrestricted administrative method.
  Future<void> saveAll(
    List<PlaylistProfile> profiles,
  ) {
    return _serialized(
      () => _saveAllUnlocked(
        List<PlaylistProfile>.of(profiles),
      ),
    );
  }

  /// Returns the number of locally stored playlist profiles.
  Future<int> count() async {
    final profiles = await load();
    return profiles.length;
  }

  /// Returns whether a new playlist can be added.
  ///
  /// Existing profiles may always be updated.
  Future<bool> canAdd({
    required bool isTrial,
    String? sourceKey,
  }) async {
    final profiles = await load();

    if (!isTrial) {
      return true;
    }

    if (sourceKey != null &&
        profiles.any(
          (profile) => profile.sourceKey == sourceKey,
        )) {
      return true;
    }

    return profiles.isEmpty;
  }

  Future<void> setActive(String sourceKey) {
    return _serialized(() async {
      final profiles = await load();

      if (!profiles.any(
        (profile) => profile.sourceKey == sourceKey,
      )) {
        return;
      }

      final updated = [
        for (final profile in profiles)
          profile.copyWith(
            isActive: profile.sourceKey == sourceKey,
          ),
      ];

      await _saveAllUnlocked(updated);
    });
  }

  /// Adds or updates a playlist.
  ///
  /// Set isTrial to true when the authenticated account
  /// currently uses the seven-day trial.
  ///
  /// The trial limit is checked inside the serialized
  /// operation to avoid simultaneous additions.
  Future<void> upsert(
    PlaylistProfile profile, {
    bool isTrial = false,
  }) {
    return _serialized(() async {
      final profiles = await load();

      final index = profiles.indexWhere(
        (existing) =>
            existing.sourceKey == profile.sourceKey,
      );

      if (isTrial && index < 0 && profiles.isNotEmpty) {
        throw StateError(
          'Während der Testphase ist nur eine Playlist '
          'gleichzeitig erlaubt. Bitte zuerst die '
          'vorhandene Playlist entfernen.',
        );
      }

      if (index >= 0) {
        final previous = profiles[index];

        profiles[index] = profile.copyWith(
          folderName: previous.folderName,
          isVisible: previous.isVisible,
          sortOrder: previous.sortOrder,
          isActive: true,
        );
      } else {
        profiles.add(
          profile.copyWith(
            sortOrder: profiles.length,
            isActive: true,
          ),
        );
      }

      final activeIndex = profiles.indexWhere(
        (existing) =>
            existing.sourceKey == profile.sourceKey,
      );

      for (var i = 0; i < profiles.length; i++) {
        profiles[i] = profiles[i].copyWith(
          isActive: i == activeIndex,
        );
      }

      await _saveAllUnlocked(profiles);
    });
  }

  /// Removes only the presentation metadata.
  ///
  /// The caller must also remove the corresponding
  /// source using PlaylistSourceStore.delete(sourceKey).
  Future<void> delete(String sourceKey) {
    return _serialized(() async {
      final profiles = await load();

      final remaining = profiles
          .where(
            (profile) => profile.sourceKey != sourceKey,
          )
          .toList();

      if (remaining.length == profiles.length) {
        return;
      }

      final hasActive = remaining.any(
        (profile) => profile.isActive,
      );

      if (!hasActive && remaining.isNotEmpty) {
        final first = remaining.first;

        remaining[0] = first.copyWith(
          isActive: true,
        );
      }

      for (var i = 0; i < remaining.length; i++) {
        remaining[i] = remaining[i].copyWith(
          sortOrder: i,
        );
      }

      await _saveAllUnlocked(remaining);
    });
  }
}

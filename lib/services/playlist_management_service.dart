
import '../models/playlist_profile.dart';
import '../models/playlist_source_config.dart';
import 'playlist_profile_store.dart';
import 'playlist_source_store.dart';

/// Coordinates playlist metadata and secure source storage.
///
/// The account's entitlement must come from the server.
/// Device limits and playlist limits are separate rules.
class PlaylistManagementService {
  PlaylistManagementService({
    PlaylistProfileStore? profileStore,
    PlaylistSourceStore? sourceStore,
  })  : _profiles = profileStore ?? PlaylistProfileStore(),
        _sources = sourceStore ?? PlaylistSourceStore();

  final PlaylistProfileStore _profiles;
  final PlaylistSourceStore _sources;

  /// A trial is identified by its server-side entitlement,
  /// not by the number of allowed devices.
  static bool isTrialAccess(
    Map<String, dynamic>? access,
  ) {
    if (access == null) return false;

    return access['has_access'] == true &&
        access['access_status'] == 'trial' &&
        access['entitlement_source'] == 'trial';
  }

  Future<List<PlaylistProfile>> loadProfiles() {
    return _profiles.load();
  }

  /// Checks whether a playlist may be imported.
  ///
  /// For trial accounts:
  /// - the first playlist is allowed
  /// - updating the same source is allowed
  /// - replacing an existing source requires confirmation
  /// - a second simultaneous playlist is not allowed
  Future<bool> requiresReplacementConfirmation({
    required String sourceKey,
    required bool isTrial,
  }) async {
    if (!isTrial) return false;

    final existing = await _profiles.load();

    if (existing.isEmpty) return false;

    return existing.any(
      (profile) => profile.sourceKey != sourceKey,
    );
  }

  /// Saves a successfully imported playlist.
  ///
  /// IMPORTANT:
  /// Call this only after the M3U parser or Xtream
  /// connection has successfully loaded its content.
  ///
  /// [replaceExistingTrialPlaylist] must be true only
  /// after the user explicitly confirms replacement.
  Future<void> saveImportedPlaylist({
    required PlaylistProfile profile,
    required PlaylistSourceConfig source,
    required bool isTrial,
    bool replaceExistingTrialPlaylist = false,
  }) async {
    if (profile.sourceKey != source.sourceKey) {
      throw StateError(
        'Playlist-Profil und Quelle stimmen nicht überein.',
      );
    }

    final existing = await _profiles.load();

    final sameIndex = existing.indexWhere(
      (item) => item.sourceKey == profile.sourceKey,
    );

    if (isTrial &&
        sameIndex < 0 &&
        existing.isNotEmpty &&
        !replaceExistingTrialPlaylist) {
      throw StateError(
        'Während der Testphase ist nur eine Playlist '
        'erlaubt. Bitte bestätige zuerst das Ersetzen.',
      );
    }

    // Never silently discard multiple pre-existing profiles.
    if (isTrial &&
        existing.length > 1 &&
        sameIndex < 0) {
      throw StateError(
        'Es sind bereits mehrere Playlist-Profile '
        'gespeichert. Bitte verwalte diese zuerst.',
      );
    }

    final oldSource = await _sources.read(
      profile.sourceKey,
    );

    // Stage the new credentials before modifying metadata.
    await _sources.save(source);

    try {
      final updated = <PlaylistProfile>[];

      if (isTrial && replaceExistingTrialPlaylist) {
        // Keep only the newly imported playlist.
        updated.add(
          profile.copyWith(
            sortOrder: 0,
            isActive: true,
          ),
        );
      } else {
        for (final item in existing) {
          if (item.sourceKey != profile.sourceKey) {
            updated.add(
              item.copyWith(isActive: false),
            );
          }
        }

        if (sameIndex >= 0) {
          final previous = existing[sameIndex];

          updated.add(
            profile.copyWith(
              folderName: previous.folderName,
              isVisible: previous.isVisible,
              sortOrder: previous.sortOrder,
              isActive: true,
            ),
          );
        } else {
          updated.add(
            profile.copyWith(
              sortOrder: updated.length,
              isActive: true,
            ),
          );
        }
      }

      await _profiles.saveAll(updated);
    } catch (_) {
      // Restore credentials when metadata saving fails.
      if (oldSource != null) {
        await _sources.save(oldSource);
      } else {
        await _sources.delete(profile.sourceKey);
      }

      rethrow;
    }

    // Only remove old credentials after the new playlist
    // metadata has been saved successfully.
    if (isTrial && replaceExistingTrialPlaylist) {
      for (final previous in existing) {
        if (previous.sourceKey != profile.sourceKey) {
          try {
            await _sources.delete(previous.sourceKey);
          } catch (_) {
            // Do not roll back the working new playlist.
            // A later cleanup can retry this deletion.
          }
        }
      }
    }
  }

  /// Removes one playlist's metadata and secure source.
  ///
  /// Does not modify:
  /// - the Supabase account
  /// - trial dates
  /// - entitlements
  /// - registered devices
  Future<void> deletePlaylist(String sourceKey) async {
    final existing = await _profiles.load();

    if (!existing.any(
      (profile) => profile.sourceKey == sourceKey,
    )) {
      return;
    }

    // Remove metadata first so the playlist no longer
    // appears in the user interface.
    await _profiles.delete(sourceKey);

    // Then delete its securely stored source.
    await _sources.delete(sourceKey);
  }
}

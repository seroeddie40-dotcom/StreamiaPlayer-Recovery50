
import '../models/playlist_profile.dart';
import '../models/playlist_source_config.dart';
import 'playlist_profile_store.dart';
import 'playlist_source_store.dart';

/// Coordinates playlist metadata and secure credentials.
///
/// Trial accounts may store one playlist at a time.
/// Paid accounts are not subject to this trial restriction.
///
/// This service never modifies devices, entitlements,
/// subscriptions or trial dates.
class PlaylistManagementService {
  PlaylistManagementService({
    PlaylistProfileStore? profileStore,
    PlaylistSourceStore? sourceStore,
  })  : _profiles = profileStore ?? PlaylistProfileStore(),
        _sources = sourceStore ?? PlaylistSourceStore();

  final PlaylistProfileStore _profiles;
  final PlaylistSourceStore _sources;

  // Serialize playlist management operations across instances.
  static Future<void> _operationTail = Future<void>.value();

  static Future<T> _serialized<T>(
    Future<T> Function() operation,
  ) {
    final result = _operationTail.then(
      (_) => operation(),
    );

    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );

    return result;
  }

  /// Determine trial status from server entitlement data.
  ///
  /// A paid Starter Pro account is NOT a trial account,
  /// even when it allows only one device.
  static bool isTrialAccess(
    Map<String, dynamic>? access,
  ) {
    if (access == null) {
      return false;
    }

    return access['has_access'] == true &&
        access['access_status'] == 'trial' &&
        access['entitlement_source'] == 'trial';
  }

  Future<List<PlaylistProfile>> loadProfiles() {
    return _profiles.load();
  }

  /// Whether adding this source would replace a different
  /// playlist during the trial.
  Future<bool> requiresReplacementConfirmation({
    required String sourceKey,
    required bool isTrial,
  }) {
    return _serialized(() async {
      if (!isTrial) {
        return false;
      }

      final existing = await _profiles.load();

      return existing.any(
        (profile) => profile.sourceKey != sourceKey,
      );
    });
  }

  /// Save a playlist after its content has loaded.
  ///
  /// A replacement is permitted only when the caller
  /// supplies an explicit user confirmation.
  ///
  /// The secure source is written first. If saving
  /// metadata fails, the previous source is restored.
  Future<void> saveImportedPlaylist({
    required PlaylistProfile profile,
    required PlaylistSourceConfig source,
    required bool isTrial,
    bool replaceExistingTrialPlaylist = false,
  }) {
    return _serialized(() async {
      final sourceKey = profile.sourceKey;

      if (sourceKey.trim().isEmpty ||
          source.sourceKey != sourceKey) {
        throw StateError(
          'Ungültige Playlist-Quelle.',
        );
      }

      final existing = await _profiles.load();

      final sameIndex = existing.indexWhere(
        (item) => item.sourceKey == sourceKey,
      );

      final otherProfiles = existing
          .where((item) => item.sourceKey != sourceKey)
          .toList();

      // Never silently remove several existing profiles.
      if (isTrial && existing.length > 1) {
        throw StateError(
          'Mehrere Playlists vorhanden. '
          'Bitte zuerst die Playlist-Verwaltung prüfen.',
        );
      }

      if (isTrial &&
          otherProfiles.isNotEmpty &&
          !replaceExistingTrialPlaylist) {
        throw StateError(
          'Während der Testphase ist nur eine Playlist '
          'gleichzeitig erlaubt. Bitte das Ersetzen '
          'der bisherigen Playlist bestätigen.',
        );
      }

      // Preserve metadata when updating the same source.
      PlaylistProfile preparedProfile;

      if (sameIndex >= 0) {
        final previous = existing[sameIndex];

        preparedProfile = profile.copyWith(
          folderName: previous.folderName,
          isVisible: previous.isVisible,
          sortOrder: previous.sortOrder,
          isActive: true,
        );
      } else {
        preparedProfile = profile.copyWith(
          sortOrder: isTrial ? 0 : existing.length,
          isActive: true,
        );
      }

      final updated = <PlaylistProfile>[];

      if (isTrial) {
        updated.add(
          preparedProfile.copyWith(
            sortOrder: 0,
            isActive: true,
          ),
        );
      } else {
        for (final item in existing) {
          if (item.sourceKey != sourceKey) {
            updated.add(
              item.copyWith(isActive: false),
            );
          }
        }

        updated.add(preparedProfile);
      }

      // Back up existing credentials for this source.
      final previousSource = await _sources.read(sourceKey);

      // Stage the new source before changing the profile list.
      await _sources.save(source);

      try {
        await _profiles.saveAll(updated);
      } catch (saveError) {
        // Attempt to restore the previous secure source.
        try {
          if (previousSource != null) {
            await _sources.save(previousSource);
          } else {
            await _sources.delete(sourceKey);
          }
        } catch (_) {
          throw StateError(
            'Playlist konnte nicht gespeichert werden. '
            'Die Wiederherstellung der Zugangsdaten '
            'ist fehlgeschlagen.',
          );
        }

        // Preserve the original storage error.
        rethrow;
      }

      // The new profile list is now committed.
      // Only then remove credentials of replaced sources.
      if (isTrial && replaceExistingTrialPlaylist) {
        for (final oldProfile in otherProfiles) {
          try {
            await _sources.delete(oldProfile.sourceKey);
          } catch (_) {
            // The old profile is already removed from the
            // visible list. Keep the new working playlist.
            //
            // Orphaned credentials require later cleanup.
          }
        }
      }
    });
  }

  /// Remove a playlist and its secure source.
  ///
  /// This operation does not affect the user's trial
  /// entitlement or registered devices.
  Future<void> deletePlaylist(String sourceKey) {
    return _serialized(() async {
      if (sourceKey.trim().isEmpty) {
        throw StateError(
          'Ungültige Playlist-Auswahl.',
        );
      }

      final existing = await _profiles.load();

      final found = existing.any(
        (profile) => profile.sourceKey == sourceKey,
      );

      if (!found) {
        return;
      }

      final remaining = existing
          .where(
            (profile) => profile.sourceKey != sourceKey,
          )
          .toList();

      // Ensure that exactly one remaining playlist
      // is marked active, if any remain.
      String? activeKey;

      for (final profile in remaining) {
        if (profile.isActive) {
          activeKey = profile.sourceKey;
          break;
        }
      }

      if (activeKey == null && remaining.isNotEmpty) {
        activeKey = remaining.first.sourceKey;
      }

      final normalized = <PlaylistProfile>[];

      for (var i = 0; i < remaining.length; i++) {
        final item = remaining[i];

        normalized.add(
          item.copyWith(
            sortOrder: i,
            isActive: item.sourceKey == activeKey,
          ),
        );
      }

      // Remove visible metadata first.
      await _profiles.saveAll(normalized);

      // Then delete the secure credentials.
      //
      // If this fails, metadata is already removed.
      // A later cleanup may be needed.
      await _sources.delete(sourceKey);
    });
  }
}

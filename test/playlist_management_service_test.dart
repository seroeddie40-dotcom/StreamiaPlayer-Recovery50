
import 'package:flutter_test/flutter_test.dart';

import 'package:streamia_player/models/playlist_profile.dart';
import 'package:streamia_player/models/playlist_source_config.dart';
import 'package:streamia_player/services/playlist_management_service.dart';
import 'package:streamia_player/services/playlist_profile_store.dart';
import 'package:streamia_player/services/playlist_source_store.dart';

class FakeProfileStore extends PlaylistProfileStore {
  List<PlaylistProfile> profiles = [];
  bool failNextSave = false;

  @override
  Future<List<PlaylistProfile>> load() async {
    return List<PlaylistProfile>.of(profiles);
  }

  @override
  Future<void> saveAll(List<PlaylistProfile> value) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated metadata failure');
    }

    profiles = List<PlaylistProfile>.of(value);
  }
}

class FakeSourceStore extends PlaylistSourceStore {
  final Map<String, PlaylistSourceConfig> sources = {};

  @override
  Future<void> save(PlaylistSourceConfig config) async {
    sources[config.sourceKey] = config;
  }

  @override
  Future<PlaylistSourceConfig?> read(String sourceKey) async {
    return sources[sourceKey];
  }

  @override
  Future<void> delete(String sourceKey) async {
    sources.remove(sourceKey);
  }
}

PlaylistProfile makeProfile(String key) {
  return PlaylistProfile(
    sourceKey: key,
    displayName: 'Playlist $key',
    type: 'm3u',
    folderName: '',
    isVisible: true,
    isActive: true,
    createdAt: DateTime(2026, 11, 13),
  );
}

PlaylistSourceConfig makeSource(String key) {
  return PlaylistSourceConfig(
    sourceKey: key,
    type: 'm3u',
    m3uUrl: 'https://example.com/$key.m3u',
  );
}

void main() {
  group('Trial entitlement detection', () {
    test('recognizes an active trial', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': true,
          'access_status': 'trial',
          'entitlement_source': 'trial',
        }),
        isTrue,
      );
    });

    test('does not mistake Starter Pro for a trial', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': true,
          'access_status': 'active',
          'entitlement_source': 'subscription',
          'max_devices': 1,
        }),
        isFalse,
      );
    });

    test('does not mistake an admin grant for a trial', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': true,
          'access_status': 'admin_grant',
          'entitlement_source': 'admin_grant',
        }),
        isFalse,
      );
    });

    test('does not accept an expired trial', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': false,
          'access_status': 'trial',
          'entitlement_source': 'trial',
        }),
        isFalse,
      );
    });
  });

  group('Playlist management', () {
    late FakeProfileStore profiles;
    late FakeSourceStore sources;
    late PlaylistManagementService service;

    setUp(() {
      profiles = FakeProfileStore();
      sources = FakeSourceStore();

      service = PlaylistManagementService(
        profileStore: profiles,
        sourceStore: sources,
      );
    });

    test('allows the first trial playlist', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: true,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('first'), isTrue);
    });

    test('rejects a second trial playlist', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: true,
      );

      await expectLater(
        service.saveImportedPlaylist(
          profile: makeProfile('second'),
          source: makeSource('second'),
          isTrial: true,
        ),
        throwsStateError,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('second'), isFalse);
    });

    test('allows a confirmed trial replacement', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: true,
      );

      await service.saveImportedPlaylist(
        profile: makeProfile('second'),
        source: makeSource('second'),
        isTrial: true,
        replaceExistingTrialPlaylist: true,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'second');
      expect(sources.sources.containsKey('first'), isFalse);
      expect(sources.sources.containsKey('second'), isTrue);
    });

    test('allows multiple paid playlists', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: false,
      );

      await service.saveImportedPlaylist(
        profile: makeProfile('second'),
        source: makeSource('second'),
        isTrial: false,
      );

      expect(profiles.profiles.length, 2);
      expect(sources.sources.length, 2);
    });

    test('keeps old playlist when metadata save fails', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: true,
      );

      profiles.failNextSave = true;

      await expectLater(
        service.saveImportedPlaylist(
          profile: makeProfile('second'),
          source: makeSource('second'),
          isTrial: true,
          replaceExistingTrialPlaylist: true,
        ),
        throwsStateError,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('first'), isTrue);
      expect(sources.sources.containsKey('second'), isFalse);
    });

    test('deletes metadata and credentials', () async {
      await service.saveImportedPlaylist(
        profile: makeProfile('first'),
        source: makeSource('first'),
        isTrial: true,
      );

      await service.deletePlaylist('first');

      expect(profiles.profiles, isEmpty);
      expect(sources.sources.containsKey('first'), isFalse);
    });
  });
}

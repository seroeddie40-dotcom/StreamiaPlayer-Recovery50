
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/playlist_profile.dart';
import '../lib/models/playlist_source_config.dart';
import '../lib/services/playlist_management_service.dart';
import '../lib/services/playlist_profile_store.dart';
import '../lib/services/playlist_source_store.dart';

class FakeProfileStore extends PlaylistProfileStore {
  List<PlaylistProfile> profiles = [];
  bool failNextSave = false;

  @override
  Future<List<PlaylistProfile>> load() async {
    return List<PlaylistProfile>.of(profiles);
  }

  @override
  Future<void> saveAll(
    List<PlaylistProfile> value,
  ) async {
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
  Future<void> save(
    PlaylistSourceConfig config,
  ) async {
    sources[config.sourceKey] = config;
  }

  @override
  Future<PlaylistSourceConfig?> read(
    String sourceKey,
  ) async {
    return sources[sourceKey];
  }

  @override
  Future<void> delete(
    String sourceKey,
  ) async {
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
  group('Entitlement detection', () {
    test('active trial is recognized', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': true,
          'access_status': 'trial',
          'entitlement_source': 'trial',
        }),
        isTrue,
      );
    });

    test('Starter Pro is not a trial', () {
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

    test('admin grant is not a trial', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': true,
          'access_status': 'admin_grant',
          'entitlement_source': 'admin_grant',
        }),
        isFalse,
      );
    });

    test('expired trial is not active', () {
      expect(
        PlaylistManagementService.isTrialAccess({
          'has_access': false,
          'access_status': 'trial',
          'entitlement_source': 'trial',
        }),
        isFalse,
      );
    });

    test('missing entitlement is not a trial', () {
      expect(
        PlaylistManagementService.isTrialAccess(null),
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

    Future<void> add(
      String key, {
      bool isTrial = true,
      bool replace = false,
    }) {
      return service.saveImportedPlaylist(
        profile: makeProfile(key),
        source: makeSource(key),
        isTrial: isTrial,
        replaceExistingTrialPlaylist: replace,
      );
    }

    test('first trial playlist is allowed', () async {
      await add('first');

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('first'), isTrue);
    });

    test('second trial playlist is rejected', () async {
      await add('first');

      await expectLater(
        add('second'),
        throwsStateError,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('second'), isFalse);
    });

    test('trial replacement requires confirmation', () async {
      await add('first');

      expect(
        await service.requiresReplacementConfirmation(
          sourceKey: 'second',
          isTrial: true,
        ),
        isTrue,
      );

      expect(
        await service.requiresReplacementConfirmation(
          sourceKey: 'first',
          isTrial: true,
        ),
        isFalse,
      );
    });

    test('confirmed trial replacement works', () async {
      await add('first');
      await add('second', replace: true);

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'second');
      expect(sources.sources.containsKey('first'), isFalse);
      expect(sources.sources.containsKey('second'), isTrue);
    });

    test('same trial playlist can be updated', () async {
      await add('first');
      await add('first');

      expect(profiles.profiles.length, 1);
      expect(sources.sources.length, 1);
    });

    test('paid accounts can store multiple playlists', () async {
      await add('first', isTrial: false);
      await add('second', isTrial: false);

      expect(profiles.profiles.length, 2);
      expect(sources.sources.length, 2);
    });

    test('old playlist survives metadata failure', () async {
      await add('first');

      profiles.failNextSave = true;

      await expectLater(
        add('second', replace: true),
        throwsStateError,
      );

      expect(profiles.profiles.length, 1);
      expect(profiles.profiles.single.sourceKey, 'first');
      expect(sources.sources.containsKey('first'), isTrue);
      expect(sources.sources.containsKey('second'), isFalse);
    });

    test('playlist deletion removes credentials', () async {
      await add('first');

      await service.deletePlaylist('first');

      expect(profiles.profiles, isEmpty);
      expect(sources.sources.containsKey('first'), isFalse);
    });

    test('concurrent trial additions cannot exceed limit', () async {
      final results = await Future.wait([
        add('first').then(
          (_) => true,
          onError: (Object _) => false,
        ),
        add('second').then(
          (_) => true,
          onError: (Object _) => false,
        ),
      ]);

      expect(results.where((success) => success).length, 1);
      expect(profiles.profiles.length, 1);
      expect(sources.sources.length, 1);
    });
  });
}

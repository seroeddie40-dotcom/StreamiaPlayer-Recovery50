import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamia_player/models/playlist_profile.dart';
import 'package:streamia_player/models/playlist_source_config.dart';
import 'package:streamia_player/services/playlist_profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('playlist profile JSON round-trip keeps display metadata', () {
    final profile = PlaylistProfile(
      sourceKey: 'src:test',
      displayName: 'Sport & Live',
      type: 'm3u',
      folderName: 'Sport',
      isVisible: false,
      isActive: true,
      sortOrder: 3,
      createdAt: DateTime.utc(2026, 11, 9),
    );
    final restored = PlaylistProfile.fromJson(profile.toJson());
    expect(restored.sourceKey, profile.sourceKey);
    expect(restored.displayName, profile.displayName);
    expect(restored.folderName, 'Sport');
    expect(restored.isVisible, isFalse);
    expect(restored.isActive, isTrue);
    expect(restored.sortOrder, 3);
  });

  test('source config JSON round-trip keeps source details separate from profile metadata', () {
    const config = PlaylistSourceConfig(
      sourceKey: 'src:secure-test', type: 'xtream', serverUrl: 'https://provider.example:8443',
      username: 'demo-user', password: 'secret-value',
    );
    final restored = PlaylistSourceConfig.fromJson(config.toJson());
    expect(restored.sourceKey, config.sourceKey);
    expect(restored.serverUrl, config.serverUrl);
    expect(restored.username, config.username);
    expect(restored.password, config.password);
  });

  test('local M3U source config round-trip preserves private file reference', () {
    const config = PlaylistSourceConfig(
      sourceKey: 'src:local-test', type: 'm3u', localFilePath: '/app-private/streamia_playlists/src_local-test.m3u',
    );
    final restored = PlaylistSourceConfig.fromJson(config.toJson());
    expect(restored.type, 'm3u');
    expect(restored.localFilePath, config.localFilePath);
    expect(restored.m3uUrl, isNull);
  });

  test('upsert makes only the newest profile active and preserves others', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlaylistProfileStore();
    final now = DateTime.utc(2026, 11, 9);
    await store.upsert(PlaylistProfile(sourceKey: 'src:a', displayName: 'Main', type: 'm3u', createdAt: now));
    await store.upsert(PlaylistProfile(sourceKey: 'src:b', displayName: 'Sports', type: 'xtream', createdAt: now));
    final profiles = await store.load();
    expect(profiles, hasLength(2));
    expect(profiles.where((p) => p.isActive).map((p) => p.sourceKey).toList(), ['src:b']);
    expect(profiles.first.displayName, 'Main');
    await store.setActive('src:a');
    final switched = await store.load();
    expect(switched.where((p) => p.isActive).map((p) => p.sourceKey).toList(), ['src:a']);
  });
}

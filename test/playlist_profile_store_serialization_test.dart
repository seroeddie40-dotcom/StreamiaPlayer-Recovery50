import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamia_player/models/playlist_profile.dart';
import 'package:streamia_player/services/playlist_profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapid activations from separate instances persist last selection', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PlaylistProfileStore();
    final second = PlaylistProfileStore();
    final now = DateTime.utc(2026, 1, 1);
    await first.saveAll([
      PlaylistProfile(sourceKey: 'src:a', displayName: 'A', type: 'm3u', createdAt: now),
      PlaylistProfile(sourceKey: 'src:b', displayName: 'B', type: 'm3u', createdAt: now),
    ]);
    await Future.wait([first.setActive('src:a'), second.setActive('src:b')]);
    final profiles = await first.load();
    expect(profiles.where((p) => p.isActive).single.sourceKey, 'src:b');
  });

  test('upsert and activation do not overwrite each other', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PlaylistProfileStore();
    final second = PlaylistProfileStore();
    final now = DateTime.utc(2026, 1, 1);
    await first.saveAll([
      PlaylistProfile(sourceKey: 'src:a', displayName: 'A', type: 'm3u', createdAt: now),
    ]);
    await Future.wait([
      second.upsert(PlaylistProfile(sourceKey: 'src:b', displayName: 'B', type: 'm3u', createdAt: now)),
      first.setActive('src:a'),
    ]);
    final profiles = await first.load();
    expect(profiles.length, 2);
    expect(profiles.where((p) => p.isActive).single.sourceKey, 'src:a');
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/models/channel.dart';
import 'package:streamia_player/providers/content_provider.dart';

Channel channel(String id) => Channel(
      id: id,
      name: id,
      streamUrl: 'https://example.org/$id',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores a recently loaded source without reloading', () {
    final provider = ContentProvider();

    provider.replaceLibrary(
      channels: [channel('a')],
      vod: [],
      series: [],
      sourceKey: 'src:a',
    );

    provider.replaceLibrary(
      channels: [channel('b')],
      vod: [],
      series: [],
      sourceKey: 'src:b',
    );

    expect(provider.activateCachedLibrary('src:a'), isTrue);
    expect(provider.sourceKey, 'src:a');
    expect(provider.channels.single.id, 'a');

    expect(
      provider.activateCachedLibrary('src:unknown'),
      isFalse,
    );
  });

  test('older asynchronous load cannot overwrite newer selection', () {
    final provider = ContentProvider();

    final oldToken = provider.beginLibraryActivation();
    final newToken = provider.beginLibraryActivation();

    expect(
      provider.replaceLibrary(
        channels: [channel('old')],
        vod: [],
        series: [],
        sourceKey: 'src:old',
        activationGeneration: oldToken,
      ),
      isFalse,
    );

    expect(
      provider.replaceLibrary(
        channels: [channel('new')],
        vod: [],
        series: [],
        sourceKey: 'src:new',
        activationGeneration: newToken,
      ),
      isTrue,
    );

    expect(provider.sourceKey, 'src:new');
    expect(provider.channels.single.id, 'new');
  });

  test('cache is bounded to three libraries including the active one', () {
    final provider = ContentProvider();

    for (var i = 0; i < 5; i++) {
      provider.replaceLibrary(
        channels: [channel('$i')],
        vod: [],
        series: [],
        sourceKey: 'src:$i',
      );
    }

    // After loading sources 0 through 4:
    // Active source: src:4
    // Cached sources: src:2 and src:3
    // Evicted sources: src:0 and src:1

    expect(provider.sourceKey, 'src:4');
    expect(provider.channels.single.id, '4');

    expect(
      provider.activateCachedLibrary('src:0'),
      isFalse,
    );

    expect(
      provider.activateCachedLibrary('src:1'),
      isFalse,
    );

    // The two most recently inactive sources remain cached.
    expect(
      provider.activateCachedLibrary('src:2'),
      isTrue,
    );

    expect(provider.sourceKey, 'src:2');
    expect(provider.channels.single.id, '2');

    // Switching back also preserves the other recent source.
    expect(
      provider.activateCachedLibrary('src:3'),
      isTrue,
    );

    expect(provider.sourceKey, 'src:3');
    expect(provider.channels.single.id, '3');
  });
}

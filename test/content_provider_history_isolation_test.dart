import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/models/channel.dart';
import 'package:streamia_player/providers/content_provider.dart';

Channel sample(String id) => Channel(
  id: id, name: id, streamUrl: 'https://example.org/$id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('history retains metadata but releases inactive channel references', () {
    final provider = ContentProvider();
    final first = sample('first');
    provider.replaceLibrary(channels: [first], vod: [], series: [], sourceKey: 'a');
    provider.addToHistory(first);
    expect(provider.recentLive.single.channel, same(first));
    provider.replaceLibrary(channels: [sample('second')], vod: [], series: [], sourceKey: 'b');
    final old = provider.recentHistory.single;
    expect(old.title, 'first');
    expect(old.sourceKey, 'a');
    expect(old.channel, isNull);
    expect(provider.recentLive, isEmpty);
    expect(provider.activateCachedLibrary('a'), isTrue);
    expect(provider.recentLive.single.channel, same(first));
  });

  test('history does not resolve a matching ID from a different source', () {
    final provider = ContentProvider();
    provider.replaceLibrary(channels: [sample('shared')], vod: [], series: [], sourceKey: 'a');
    provider.addToHistory(provider.channels.single);
    provider.replaceLibrary(channels: [sample('shared')], vod: [], series: [], sourceKey: 'b');
    expect(provider.recentLive, isEmpty);
    expect(provider.recentHistory.single.channel, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/providers/content_provider.dart';
import 'package:streamia_player/services/playlist_parser.dart';

void main() {
  test('M3U parser loads a valid live channel', () async {
    final provider = ContentProvider();
    const playlist = '#EXTM3U\n#EXTINF:-1 tvg-id="news" group-title="News",News HD\nhttps://example.org/live.m3u8\n';
    await PlaylistParser.parseAndLoad(playlist, provider);
    expect(provider.channels, hasLength(1));
    expect(provider.channels.single.name, 'News HD');
    expect(provider.channels.single.epgChannelId, 'news');
    expect(provider.isLoaded, isTrue);
  });

  test('M3U parser rejects invalid input', () async {
    final provider = ContentProvider();
    expect(
      () => PlaylistParser.parseAndLoad('not a playlist', provider),
      throwsFormatException,
    );
  });
}

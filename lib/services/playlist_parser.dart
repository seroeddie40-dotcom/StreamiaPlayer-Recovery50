import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import '../providers/content_provider.dart';

/// Parses a user-supplied M3U playlist. The app does not provide channel content.
class PlaylistParser {
  static Future<void> parseAndLoad(String urlOrContent, ContentProvider content, {String? sourceKeyOverride, int? activationGeneration}) async {
    final input = urlOrContent.trim();
    if (input.isEmpty) throw const FormatException('Die Playlist ist leer.');

    var text = input;
    if (_looksLikeUrl(input)) {
      final uri = Uri.tryParse(input);
      if (uri == null || !uri.hasScheme || !{'http', 'https'}.contains(uri.scheme)) {
        throw const FormatException('Bitte eine gültige HTTP- oder HTTPS-Playlist-URL eingeben.');
      }
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Playlist konnte nicht geladen werden (HTTP ${response.statusCode}).');
      }
      text = response.body;
    }

    if (!text.trimLeft().startsWith('#EXTM3U')) {
      throw const FormatException('Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.');
    }

    String stableStreamIdentity(String value) {
      final uri = Uri.tryParse(value);
      if (uri == null) return sha256.convert(utf8.encode(value)).toString();
      // Never fingerprint user-info, query tokens, or arbitrary path segments:
      // some Xtream-style M3U URLs embed usernames/passwords in the path.
      final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}${uri.hasPort ? ':${uri.port}' : ''}/$lastSegment';
    }
    String stableId(String kind, String value) =>
        '${kind}_${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';

    final channels = <Channel>[];
    final vod = <VodItem>[];
    final series = <String, Series>{};
    String? name, logo, group, tvgId, pendingUrl;
    var episodeCounter = <String, int>{};

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 && comma < line.length - 1
            ? line.substring(comma + 1).trim()
            : _attribute(line, 'tvg-name') ?? 'Unbenannter Eintrag';
        logo = _attribute(line, 'tvg-logo');
        group = _attribute(line, 'group-title');
        tvgId = _attribute(line, 'tvg-id');
        pendingUrl = null;
        continue;
      }
      if (line.startsWith('#') || name == null) continue;
      final uri = Uri.tryParse(line);
      if (uri == null || !{'http', 'https', 'rtsp', 'rtmp'}.contains(uri.scheme)) continue;
      pendingUrl = line;

      final normalizedGroup = (group ?? '').toLowerCase();
      final normalizedName = name.toLowerCase();
      final looksSeries = normalizedGroup.contains('series') ||
          normalizedGroup.contains('serie') ||
          normalizedGroup.contains('tv show');
      final looksVod = normalizedGroup.contains('movie') ||
          normalizedGroup.contains('vod') ||
          normalizedGroup.contains('film') ||
          _hasVideoExtension(uri.path);

      if (looksSeries) {
        // M3U has no standard season/episode schema. Keep each listed item as
        // an episode under its group instead of pretending metadata exists.
        final key = group!.trim();
        final number = (episodeCounter[key] ?? 0) + 1;
        episodeCounter[key] = number;
        final episode = Episode(
          id: stableId('m3u_ep', '$key|$number|$name|${stableStreamIdentity(pendingUrl)}'),
          title: name,
          number: number,
          streamUrl: pendingUrl,
        );
        final existing = series[key];
        if (existing == null) {
          series[key] = Series(
            id: stableId('m3u_series', key),
            title: key,
            posterUrl: logo,
            seasons: [Season(number: 1, episodes: [episode])],
          );
        } else {
          existing.seasons.first.episodes.add(episode);
        }
      } else if (looksVod) {
        vod.add(VodItem(
          id: stableId('m3u_vod', '$name|${stableStreamIdentity(pendingUrl)}'),
          title: name,
          posterUrl: logo,
          streamUrl: pendingUrl,
        ));
      } else {
        channels.add(Channel(
          id: stableId('m3u_ch', '$name|${stableStreamIdentity(pendingUrl)}'),
          name: name,
          streamUrl: pendingUrl,
          logoUrl: logo,
          category: group,
          epgChannelId: tvgId,
        ));
      }
      name = logo = group = tvgId = pendingUrl = null;
    }

    if (channels.isEmpty && vod.isEmpty && series.isEmpty) {
      throw const FormatException('Die Playlist enthält keine erkennbaren Einträge.');
    }
    // Build the source fingerprint from playlist identity + descriptive metadata,
    // not from volatile signed stream query strings. The raw URL/credentials are never stored.
    final sourceDescriptor = <String>[
      ...channels.map((c) => 'live|${c.id}'),
      ...vod.map((v) => 'vod|${v.id}'),
      ...series.values.map((v) => 'series|${v.id}'),
    ]..sort();
    final parsedUri = _looksLikeUrl(input) ? Uri.tryParse(input) : null;
    final sourceIdentity = 'm3u-v2|${parsedUri == null ? 'file' : parsedUri.host.toLowerCase()}|${sourceDescriptor.join('\n')}';
    final sourceKey = sourceKeyOverride ?? 'src:v1:${sha256.convert(utf8.encode(sourceIdentity)).toString()}';
    content.replaceLibrary(channels: channels, vod: vod, series: series,
      sourceKey: sourceKey, sourceLabel: parsedUri?.host ?? 'M3U-Datei',
      activationGeneration: activationGeneration);
  }

  static bool _looksLikeUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static String? _attribute(String line, String key) {
    final escaped = RegExp.escape(key);
    return RegExp('$escaped="([^"]*)"', caseSensitive: false)
        .firstMatch(line)?.group(1);
  }

  static bool _hasVideoExtension(String path) =>
      RegExp(r'\.(mp4|mkv|avi|mov|m4v|webm)$', caseSensitive: false).hasMatch(path);
}

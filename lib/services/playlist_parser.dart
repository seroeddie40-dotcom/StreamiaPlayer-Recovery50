import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import '../providers/content_provider.dart';

/// Parses user-supplied M3U playlists. Streamia provides no streams.
class PlaylistParser {
  static Future<void> parseAndLoad(
    String urlOrContent,
    ContentProvider content, {
    String? sourceKeyOverride,
    int? activationGeneration,
  }) async {
    final input = urlOrContent.trim();
    if (input.isEmpty) throw const FormatException('Die Playlist ist leer.');
    if (_looksLikeUrl(input)) {
      final uri = Uri.tryParse(input);
      if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
        throw const FormatException('Bitte eine gültige HTTP- oder HTTPS-Playlist-URL eingeben.');
      }
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 30));
        final response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw HttpException('Playlist konnte nicht geladen werden (HTTP ${response.statusCode}).');
        }
        await _parseLines(
          response.transform(utf8.decoder).transform(const LineSplitter()),
          content,
          sourceKeyOverride: sourceKeyOverride,
          activationGeneration: activationGeneration,
          sourceHost: uri.host,
        );
      } finally {
        client.close();
      }
    } else {
      await _parseLines(
        Stream<String>.fromIterable(const LineSplitter().convert(input)),
        content,
        sourceKeyOverride: sourceKeyOverride,
        activationGeneration: activationGeneration,
      );
    }
  }

  /// Imports local M3U files without materializing the whole file as a String.
  /// The picker should provide a readable temporary file path on Android.
  static Future<void> parseAndLoadFile(
    String path,
    ContentProvider content, {
    String? sourceKeyOverride,
    int? activationGeneration,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('Die ausgewählte M3U-Datei ist nicht mehr verfügbar.');
    }
    await _parseLines(
      file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
      content,
      sourceKeyOverride: sourceKeyOverride,
      activationGeneration: activationGeneration,
    );
  }

  static Future<void> _parseLines(
    Stream<String> lines,
    ContentProvider content, {
    String? sourceKeyOverride,
    int? activationGeneration,
    String? sourceHost,
  }) async {
    final channels = <Channel>[];
    final vod = <VodItem>[];
    final series = <String, Series>{};
    final episodeCounter = <String, int>{};
    final descriptors = <String>[];
    String? name, logo, group, tvgId;
    bool headerSeen = false;

    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (!headerSeen) {
        if (line.startsWith('\uFEFF')) {
          if (!line.substring(1).startsWith('#EXTM3U')) {
            throw const FormatException('Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.');
          }
        } else if (!line.startsWith('#EXTM3U')) {
          throw const FormatException('Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.');
        }
        headerSeen = true;
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 && comma < line.length - 1
            ? line.substring(comma + 1).trim()
            : _attribute(line, 'tvg-name') ?? 'Unbenannter Eintrag';
        logo = _attribute(line, 'tvg-logo');
        group = _attribute(line, 'group-title');
        tvgId = _attribute(line, 'tvg-id');
        continue;
      }
      if (line.startsWith('#') || name == null) continue;
      final uri = Uri.tryParse(line);
      if (uri == null || !{'http', 'https', 'rtsp', 'rtmp'}.contains(uri.scheme)) continue;
      final identity = _stableStreamIdentity(line);
      final normalizedGroup = (group ?? '').toLowerCase();
      final looksSeries = normalizedGroup.contains('series') ||
          normalizedGroup.contains('serie') || normalizedGroup.contains('tv show');
      final looksVod = normalizedGroup.contains('movie') ||
          normalizedGroup.contains('vod') || normalizedGroup.contains('film') ||
          _hasVideoExtension(uri.path);

      if (looksSeries) {
        final key = (group ?? '').trim();
        final number = (episodeCounter[key] ?? 0) + 1;
        episodeCounter[key] = number;
        final episode = Episode(
          id: _stableId('m3u_ep', '$key|$number|$name|$identity'),
          title: name,
          number: number,
          streamUrl: line,
        );
        final existing = series[key];
        if (existing == null) {
          final created = Series(
            id: _stableId('m3u_series', key),
            title: key,
            posterUrl: logo,
            seasons: [Season(number: 1, episodes: [episode])],
          );
          series[key] = created;
          descriptors.add('series|${created.id}');
        } else {
          existing.seasons.first.episodes.add(episode);
        }
      } else if (looksVod) {
        final item = VodItem(
          id: _stableId('m3u_vod', '$name|$identity'),
          title: name,
          posterUrl: logo,
          streamUrl: line,
        );
        vod.add(item);
        descriptors.add('vod|${item.id}');
      } else {
        final item = Channel(
          id: _stableId('m3u_ch', '$name|$identity'),
          name: name,
          streamUrl: line,
          logoUrl: logo,
          category: group,
          epgChannelId: tvgId,
        );
        channels.add(item);
        descriptors.add('live|${item.id}');
      }
      name = null;
      logo = null;
      group = null;
      tvgId = null;
    }

    if (!headerSeen) {
      throw const FormatException('Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.');
    }
    if (channels.isEmpty && vod.isEmpty && series.isEmpty) {
      throw const FormatException('Die Playlist enthält keine erkennbaren Einträge.');
    }
    descriptors.sort();
    final sourceIdentity = 'm3u-v2|${sourceHost?.toLowerCase() ?? 'file'}|${descriptors.join('\n')}';
    final sourceKey = sourceKeyOverride ??
        'src:v1:${sha256.convert(utf8.encode(sourceIdentity))}';
    content.replaceLibrary(
      channels: channels,
      vod: vod,
      series: series.values.toList(),
      sourceKey: sourceKey,
      sourceLabel: sourceHost ?? 'M3U-Datei',
      activationGeneration: activationGeneration,
    );
  }

  static String _stableStreamIdentity(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return sha256.convert(utf8.encode(value)).toString();
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
        '${uri.hasPort ? ':${uri.port}' : ''}/$lastSegment';
  }

  static String _stableId(String kind, String value) =>
      '${kind}_${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';

  static bool _looksLikeUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static String? _attribute(String line, String key) => RegExp(
        '${RegExp.escape(key)}="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(line)?.group(1);

  static bool _hasVideoExtension(String path) => RegExp(
        r'\.(mp4|mkv|avi|mov|m4v|webm)$',
        caseSensitive: false,
      ).hasMatch(path);
}

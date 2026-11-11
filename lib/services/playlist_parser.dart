import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import '../providers/content_provider.dart';

/// Parses user-supplied M3U playlists. Streamia provides no streams.
///
/// Reads network and local playlists line by line. Keeps the original
/// group-title as a category for Live TV, VOD and series.
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
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException(
          'Bitte eine gültige HTTP- oder HTTPS-Playlist-URL eingeben.',
        );
      }
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      try {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 30));
        final response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Playlist konnte nicht geladen werden (HTTP ${response.statusCode}).',
          );
        }
        await _parseLines(
          response.transform(utf8.decoder).transform(const LineSplitter()),
          content,
          sourceKeyOverride: sourceKeyOverride,
          activationGeneration: activationGeneration,
          sourceHost: uri.host,
        );
      } finally {
        client.close(force: true);
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

  /// The picker should supply a readable temporary path on Android.
  /// The file itself is not loaded into one large String.
  static Future<void> parseAndLoadFile(
    String path,
    ContentProvider content, {
    String? sourceKeyOverride,
    int? activationGeneration,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException(
        'Die ausgewählte M3U-Datei ist nicht mehr verfügbar.',
      );
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

    String? name;
    String? logo;
    String? group;
    String? tvgId;
    bool headerSeen = false;

    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (!headerSeen) {
        final header = line.startsWith('\uFEFF') ? line.substring(1) : line;
        if (!header.startsWith('#EXTM3U')) {
          throw const FormatException(
            'Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.',
          );
        }
        headerSeen = true;
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 && comma < line.length - 1
            ? line.substring(comma + 1).trim()
            : _attribute(line, 'tvg-name') ?? 'Unbenannter Eintrag';
        if (name.isEmpty) name = 'Unbenannter Eintrag';
        logo = _clean(_attribute(line, 'tvg-logo'));
        group = _clean(_attribute(line, 'group-title'));
        tvgId = _clean(_attribute(line, 'tvg-id'));
        continue;
      }

      // Some providers specify the group on a separate line.
      if (line.startsWith('#EXTGRP:') && name != null) {
        group = _clean(line.substring('#EXTGRP:'.length)) ?? group;
        continue;
      }
      if (line.startsWith('#') || name == null) continue;

      final uri = Uri.tryParse(line);
      if (uri == null ||
          !{'http', 'https', 'rtsp', 'rtmp'}.contains(uri.scheme.toLowerCase()) ||
          (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
        continue;
      }

      final itemName = name;
      final itemGroup = group;
      final identity = _stableStreamIdentity(line);
      final normalizedGroup = (itemGroup ?? '').toLowerCase();
      final path = uri.path.toLowerCase();

      // Group names vary by provider and language. Prefer explicit stream
      // paths when present; never infer a series from a generic film group.
      final looksSeries = _seriesGroup(normalizedGroup) ||
          path.contains('/series/') ||
          path.contains('/serie/');
      final looksVod = !looksSeries &&
          (_movieGroup(normalizedGroup) ||
              path.contains('/movie/') ||
              path.contains('/vod/') ||
              _hasVideoExtension(uri.path));

      if (looksSeries) {
        final episodeInfo = _episodeInfo(itemName);
        final seriesTitle = episodeInfo.title;
        final seriesCategory = itemGroup;
        final seriesKey = '${seriesCategory ?? ''}\u0000${seriesTitle.toLowerCase()}';
        final seasonNumber = episodeInfo.season ?? 1;
        final counterKey = '$seriesKey\u0000$seasonNumber';
        final episodeNumber = episodeInfo.episode ??
            ((episodeCounter[counterKey] ?? 0) + 1);
        if (episodeNumber > (episodeCounter[counterKey] ?? 0)) {
          episodeCounter[counterKey] = episodeNumber;
        }

        final episode = Episode(
          id: _stableId('m3u_ep', '$seriesKey|$seasonNumber|$episodeNumber|$identity'),
          title: itemName,
          number: episodeNumber,
          streamUrl: line,
        );
        final existing = series[seriesKey];
        if (existing == null) {
          final created = Series(
            id: _stableId('m3u_series', seriesKey),
            title: seriesTitle,
            genre: seriesCategory,
            posterUrl: logo,
            seasons: [Season(number: seasonNumber, episodes: [episode])],
          );
          series[seriesKey] = created;
          descriptors.add('series|${created.id}');
        } else {
          Season? target;
          for (final season in existing.seasons) {
            if (season.number == seasonNumber) {
              target = season;
              break;
            }
          }
          if (target == null) {
            target = Season(number: seasonNumber, episodes: <Episode>[]);
            existing.seasons.add(target);
          }
          target.episodes.add(episode);
        }
      } else if (looksVod) {
        final item = VodItem(
          id: _stableId('m3u_vod', '$itemName|$identity'),
          title: itemName,
          genre: itemGroup,
          posterUrl: logo,
          streamUrl: line,
        );
        vod.add(item);
        descriptors.add('vod|${item.id}');
      } else {
        final item = Channel(
          id: _stableId('m3u_ch', '$itemName|$identity'),
          name: itemName,
          streamUrl: line,
          logoUrl: logo,
          category: itemGroup,
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
      throw const FormatException(
        'Ungültige M3U-Datei: #EXTM3U-Kopfzeile fehlt.',
      );
    }
    if (channels.isEmpty && vod.isEmpty && series.isEmpty) {
      throw const FormatException(
        'Die Playlist enthält keine erkennbaren Einträge.',
      );
    }

    // Keep source-key behavior compatible with the existing parser.
    descriptors.sort();
    final sourceIdentity =
        'm3u-v2|${sourceHost?.toLowerCase() ?? 'file'}|${descriptors.join('\n')}';
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

  static bool _seriesGroup(String group) =>
      RegExp(r'(^|[^a-z])(series|serie|serien|serial|seriale|dizi|diziler|tv show|tv shows)([^a-z]|$)')
          .hasMatch(group);

  static bool _movieGroup(String group) =>
      RegExp(r'(^|[^a-z])(movie|movies|vod|film|filme|films|filmler|sinema|cinema)([^a-z]|$)')
          .hasMatch(group);

  static _EpisodeInfo _episodeInfo(String rawTitle) {
    // E.g. "Example Show S02E04", "Example Show 2x04".
    final match = RegExp(
      r'\b(?:s(\d{1,2})\s*e(\d{1,3})|(\d{1,2})x(\d{1,3}))\b',
      caseSensitive: false,
    ).firstMatch(rawTitle);
    if (match != null) {
      final season = int.tryParse(match.group(1) ?? match.group(3) ?? '');
      final episode = int.tryParse(match.group(2) ?? match.group(4) ?? '');
      final title = rawTitle.substring(0, match.start)
          .replaceAll(RegExp(r'[\s\-_.:|]+$'), '')
          .trim();
      if (title.isNotEmpty) {
        return _EpisodeInfo(title, season, episode);
      }
    }
    // Without an episode pattern, retain the complete name rather than
    // incorrectly combining every show in the same provider category.
    return _EpisodeInfo(rawTitle, null, null);
  }

  static String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
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

class _EpisodeInfo {
  final String title;
  final int? season;
  final int? episode;
  const _EpisodeInfo(this.title, this.season, this.episode);
}

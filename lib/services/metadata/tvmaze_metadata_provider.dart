import 'dart:convert';
import 'package:http/http.dart' as http;
import 'metadata_provider.dart';
import 'metadata_record.dart';
import 'episode_metadata_record.dart';

/// Free public TVmaze API adapter for TV series only.
/// TVmaze data is licensed CC BY-SA; attribution and ShareAlike obligations
/// must be respected. Image reuse requires a separate rights review.
class TvMazeMetadataProvider implements MetadataProvider {
  final http.Client _client;
  final Duration timeout;

  TvMazeMetadataProvider({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  @override
  String get id => 'tvmaze';
  @override
  String get displayName => 'TVmaze';
  @override
  bool supports(String mediaType) => mediaType.toLowerCase() == 'series' || mediaType.toLowerCase() == 'tv';

  @override
  Future<List<MetadataRecord>> search({required String title, String? year, String language = 'en'}) async {
    final query = title.trim();
    if (query.isEmpty) return const [];
    final uri = Uri.https('api.tvmaze.com', '/search/shows', {'q': query});
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'StreamiaPlayer/1.0 (metadata lookup)',
    }).timeout(timeout);
    if (response.statusCode == 429) {
      throw const TvMazeRateLimitException();
    }
    if (response.statusCode != 200) {
      throw TvMazeApiException('TVmaze antwortete mit HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final results = <MetadataRecord>[];
    for (final item in decoded) {
      if (item is! Map || item['show'] is! Map) continue;
      final show = item['show'] as Map;
      final premiered = _string(show['premiered']);
      if (year != null && year.isNotEmpty && premiered != null && !premiered.startsWith(year)) continue;
      final image = show['image'] is Map ? show['image'] as Map : const {};
      final genres = show['genres'] is List
          ? (show['genres'] as List).whereType<String>().toList(growable: false)
          : const <String>[];
      final rating = show['rating'] is Map ? (show['rating'] as Map)['average'] : null;
      results.add(MetadataRecord(
        providerId: '${show['id']}',
        providerName: displayName,
        mediaType: 'series',
        title: _string(show['name']) ?? query,
        summary: _cleanHtml(_string(show['summary'])),
        premiered: premiered,
        genres: genres,
        posterUrl: _string(image['original']) ?? _string(image['medium']),
        sourceUrl: _string(show['url']),
        attribution: 'Datenquelle: TVmaze (tvmaze.com)',
        license: 'CC BY-SA',
        rating: double.tryParse('$rating'),
      ));
    }
    return results;
  }

  /// Loads episode metadata for a confirmed TVmaze show ID. The caller must
  /// have selected/matched the show first; this method never guesses a show.
  Future<List<EpisodeMetadataRecord>> fetchEpisodes(String showId) async {
    final id = int.tryParse(showId);
    if (id == null) return const [];
    final uri = Uri.https('api.tvmaze.com', '/shows/$id/episodes');
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'StreamiaPlayer/1.0 (metadata lookup)',
    }).timeout(timeout);
    if (response.statusCode == 429) throw const TvMazeRateLimitException();
    if (response.statusCode != 200) {
      throw TvMazeApiException('TVmaze Episodenabruf: HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((episode) {
      final image = episode['image'] is Map ? episode['image'] as Map : const {};
      final season = int.tryParse('${episode['season'] ?? ''}');
      final number = int.tryParse('${episode['number'] ?? ''}');
      if (season == null || number == null) return null;
      final runtime = int.tryParse('${episode['runtime'] ?? ''}');
      return EpisodeMetadataRecord(
        season: season,
        number: number,
        title: _string(episode['name']),
        summary: _cleanHtml(_string(episode['summary'])),
        airDate: _string(episode['airdate']),
        imageUrl: _string(image['original']) ?? _string(image['medium']),
        runtimeMinutes: runtime,
        providerId: '${episode['id']}',
        attribution: 'Datenquelle: TVmaze (tvmaze.com)',
        license: 'CC BY-SA',
        sourceUrl: _string(episode['url']),
      );
    }).whereType<EpisodeMetadataRecord>().toList(growable: false);
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _cleanHtml(String? value) {
    if (value == null) return null;
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  void close() => _client.close();
}

class TvMazeRateLimitException implements Exception {
  const TvMazeRateLimitException();
  @override
  String toString() => 'TVmaze rate limit reached; retry later.';
}

class TvMazeApiException implements Exception {
  final String message;
  const TvMazeApiException(this.message);
  @override
  String toString() => message;
}

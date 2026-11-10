import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';

/// Client for a user-provided Xtream-compatible account.
class XtreamService {
  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;
  final Duration requestTimeout;
  final Duration retryDelay;
  final int maxAttempts;

  XtreamService({
    required String baseUrl,
    required this.username,
    required this.password,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 25),
    this.retryDelay = const Duration(milliseconds: 350),
    this.maxAttempts = 2,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  static String _normalizeBaseUrl(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        !{'http', 'https'}.contains(parsed.scheme) ||
        parsed.host.isEmpty) {
      throw const FormatException('Ungültige Server-Adresse. Bitte HTTP(S) inklusive Host eingeben.');
    }
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  Uri _apiUri(Map<String, String> extra) {
    return Uri.parse('$baseUrl/player_api.php').replace(queryParameters: {
      'username': username,
      'password': password,
      ...extra,
    });
  }

  /// A retry is only performed for temporary transport/server failures.
  /// Never include API response bodies or credential-bearing URLs in errors.
  Future<dynamic> _request(Map<String, String> params) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _client.get(_apiUri(params)).timeout(requestTimeout);
        if ({429, 502, 503, 504}.contains(response.statusCode)) {
          if (attempt < attempts) {
            await Future<void>.delayed(retryDelay);
            continue;
          }
          throw const XtreamConnectionException('Xtream-Server vorübergehend nicht erreichbar. Bitte später erneut versuchen.');
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const XtreamConnectionException('Xtream-Zugang abgelehnt. Bitte Zugangsdaten prüfen.');
        }
        if (response.statusCode != 200) {
          throw XtreamConnectionException('Xtream-Serverfehler (HTTP ${response.statusCode}).');
        }
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw const FormatException('Ungültige JSON-Antwort vom Xtream-Server.');
        }
        if (decoded is Map && decoded['user_info'] is Map) {
          final info = decoded['user_info'] as Map;
          if (info['auth'] == 0 || info['auth'] == '0' ||
              info['status'] == 'Disabled' || info['status'] == 'Banned') {
            throw const XtreamConnectionException('Xtream-Zugang ist ungültig oder deaktiviert.');
          }
        }
        if (decoded is Map && decoded['error'] != null) {
          throw const XtreamConnectionException('Xtream-Server meldet einen API-Fehler.');
        }
        return decoded;
      } on TimeoutException {
        if (attempt == attempts) {
          throw const XtreamConnectionException('Zeitüberschreitung beim Xtream-Server. Bitte Verbindung prüfen.');
        }
      } on SocketException {
        if (attempt == attempts) {
          throw const XtreamConnectionException('Keine Netzwerkverbindung zum Xtream-Server.');
        }
      } on http.ClientException {
        if (attempt == attempts) {
          throw const XtreamConnectionException('Xtream-Netzwerkfehler. Bitte Verbindung prüfen.');
        }
      }
      await Future<void>.delayed(retryDelay);
    }
    throw const XtreamConnectionException('Xtream-Verbindung fehlgeschlagen.');
  }

  Future<List<Channel>> getLiveStreams({int? categoryId}) async {
    final data = await _request({
      'action': 'get_live_streams',
      if (categoryId != null) 'category_id': '$categoryId',
    });
    if (data is! List) throw const FormatException('Unerwartete Live-TV-Antwort.');
    return data.map((item) {
      final j = item as Map<String, dynamic>;
      final id = '${j['stream_id']}';
      final ext = (j['container_extension'] ?? 'ts').toString();
      return Channel(
        id: id,
        name: (j['name'] ?? 'Unbekannter Sender').toString(),
        streamUrl: '$baseUrl/live/${Uri.encodeComponent(username)}/${Uri.encodeComponent(password)}/$id.$ext',
        logoUrl: _nullable(j['stream_icon']),
        category: _nullable(j['category_name']),
        epgChannelId: _nullable(j['epg_channel_id']),
      );
    }).toList();
  }

  Future<List<VodItem>> getVodStreams({int? categoryId}) async {
    final data = await _request({
      'action': 'get_vod_streams',
      if (categoryId != null) 'category_id': '$categoryId',
    });
    if (data is! List) throw const FormatException('Unerwartete VOD-Antwort.');
    return data.map((item) {
      final j = item as Map<String, dynamic>;
      final id = '${j['stream_id']}';
      final ext = (j['container_extension'] ?? 'mp4').toString();
      return VodItem(
        id: id,
        title: (j['name'] ?? 'Unbekannter Film').toString(),
        plot: _nullable(j['plot']),
        posterUrl: _nullable(j['stream_icon']) ?? _nullable(j['cover_big']) ?? _nullable(j['cover']),
        backdropUrl: _firstString(j['backdrop_path']),
        genre: _nullable(j['genre']),
        releaseDate: _nullable(j['releasedate']) ?? _nullable(j['releaseDate']),
        ageRating: _nullable(j['rating_age']),
        director: _nullable(j['director']),
        cast: _nullable(j['cast']),
        rating: double.tryParse('${j['rating'] ?? ''}'),
        externalMetadataId: _nullable(j['tmdb_id']) ?? _nullable(j['imdb_id']),
        metadataSource: 'xtream',
        streamUrl: '$baseUrl/movie/${Uri.encodeComponent(username)}/${Uri.encodeComponent(password)}/$id.$ext',
        durationSeconds: int.tryParse('${j['duration_secs'] ?? ''}') ?? _durationFromText(j['duration']),
      );
    }).toList();
  }

  /// Loads only the series catalog. Fetching every series' episodes here would
  /// make large IPTV imports require thousands of sequential HTTP requests.
  Future<List<Series>> getSeries({int? categoryId}) async {
    final data = await _request({
      'action': 'get_series',
      if (categoryId != null) 'category_id': '$categoryId',
    });
    if (data is! List) throw const FormatException('Unerwartete Serien-Antwort.');
    return data.map<Series>((item) {
      if (item is! Map) throw const FormatException('Ungültiger Serieneintrag.');
      final j = Map<String, dynamic>.from(item);
      return Series(
        id: '${j['series_id']}',
        title: (j['name'] ?? 'Unbekannte Serie').toString(),
        plot: _nullable(j['plot']),
        posterUrl: _nullable(j['cover_big']) ?? _nullable(j['cover']),
        backdropUrl: _firstString(j['backdrop_path']),
        genre: _nullable(j['genre']),
        releaseDate: _nullable(j['releaseDate']) ?? _nullable(j['release_date']),
        ageRating: _nullable(j['rating_age']),
        cast: _nullable(j['cast']),
        director: _nullable(j['director']),
        rating: double.tryParse('${j['rating'] ?? ''}'),
        externalMetadataId: _nullable(j['tmdb_id']),
        metadataSource: 'xtream',
        seasons: const [],
      );
    }).toList(growable: false);
  }

  /// Call when the user opens a series. The caller must update the content
  /// provider with the returned series before rendering episode playback.
  Future<Series> getSeriesDetails(Series catalogSeries) async {
    final details = await _request({
      'action': 'get_series_info',
      'series_id': catalogSeries.id,
    });
    if (details is! Map) {
      throw const FormatException('Unerwartete Serien-Detailantwort.');
    }
    final info = details['info'] is Map ? details['info'] as Map : const {};
    final episodesRaw = details['episodes'];
    final seasons = <Season>[];
    if (episodesRaw is Map) {
      final keys = episodesRaw.keys.toList()
        ..sort((a, b) => (int.tryParse('$a') ?? 0).compareTo(int.tryParse('$b') ?? 0));
      for (final key in keys) {
        final rawList = episodesRaw[key];
        if (rawList is! List) continue;
        final episodes = <Episode>[];
        for (var i = 0; i < rawList.length; i++) {
          final rawEpisode = rawList[i];
          if (rawEpisode is! Map) continue;
          final e = rawEpisode;
          final epId = '${e['id']}';
          final ext = (e['container_extension'] ?? 'mp4').toString();
          final epInfo = e['info'] is Map ? e['info'] as Map : const {};
          episodes.add(Episode(
            id: epId,
            title: (e['title'] ?? e['name'] ?? 'Folge ${i + 1}').toString(),
            number: int.tryParse('${e['episode_num'] ?? i + 1}') ?? i + 1,
            streamUrl: '$baseUrl/series/${Uri.encodeComponent(username)}/${Uri.encodeComponent(password)}/$epId.$ext',
            plot: _nullable(epInfo['plot']),
            stillUrl: _nullable(epInfo['movie_image']),
            releaseDate: _nullable(epInfo['releasedate']),
            durationSeconds: int.tryParse('${epInfo['duration_secs'] ?? ''}') ?? _durationFromText(epInfo['duration']),
          ));
        }
        seasons.add(Season(number: int.tryParse('$key') ?? seasons.length + 1, episodes: episodes));
      }
    }
    final enriched = catalogSeries.copyWith(
      plot: _nullable(info['plot']),
      posterUrl: _nullable(info['cover']),
      backdropUrl: _firstString(info['backdrop_path']),
      genre: _nullable(info['genre']),
      releaseDate: _nullable(info['releaseDate']),
      ageRating: _nullable(info['rating_age']),
      cast: _nullable(info['cast']),
      director: _nullable(info['director']),
      rating: double.tryParse('${info['rating'] ?? ''}'),
      externalMetadataId: _nullable(info['tmdb_id']),
    );
    return Series(
      id: enriched.id, title: enriched.title, plot: enriched.plot,
      posterUrl: enriched.posterUrl, backdropUrl: enriched.backdropUrl,
      genre: enriched.genre, releaseDate: enriched.releaseDate,
      ageRating: enriched.ageRating, cast: enriched.cast,
      director: enriched.director, rating: enriched.rating,
      externalMetadataId: enriched.externalMetadataId,
      metadataSource: enriched.metadataSource,
      metadataProviderId: enriched.metadataProviderId,
      metadataAttribution: enriched.metadataAttribution,
      metadataLicense: enriched.metadataLicense,
      metadataSourceUrl: enriched.metadataSourceUrl,
      seasons: seasons,
    );
  }

  static String? _firstString(dynamic value) {
    if (value is List) {
      for (final item in value) {
        final candidate = _nullable(item);
        if (candidate != null) return candidate;
      }
    }
    return _nullable(value);
  }

  static int? _durationFromText(dynamic value) {
    if (value == null) return null;
    final match = RegExp(r'^(?:(\d+)\s*[:h]\s*)?(\d+)\s*[:m]\s*(\d+)?', caseSensitive: false).firstMatch(value.toString().trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  static String? _nullable(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }

  void close() => _client.close();
}

/// Safe error text: no account details, URLs or server response bodies.
class XtreamConnectionException implements Exception {
  final String message;
  const XtreamConnectionException(this.message);
  @override
  String toString() => message;
}

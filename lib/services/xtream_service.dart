
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

  /// Optional identity of the playlist that owns this client.
  /// Must match PlaylistProfile.sourceKey.
  final String? sourceKey;

  final http.Client _client;
  final Duration requestTimeout;
  final Duration retryDelay;
  final int maxAttempts;

  XtreamService({
    required String baseUrl,
    required this.username,
    required this.password,
    this.sourceKey,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 25),
    this.retryDelay = const Duration(milliseconds: 350),
    this.maxAttempts = 2,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  // Cache category lookups per service instance,
  // including concurrent calls.
  final Map<String, Future<Map<String, String>>>
      _categoryRequests = {};

  Future<Map<String, String>> _categoryNames(
    String action,
  ) =>
      _categoryRequests.putIfAbsent(action, () async {
        try {
          final data = await _request({'action': action});
          if (data is! List) {
            return <String, String>{};
          }

          final names = <String, String>{};

          for (final item in data) {
            if (item is! Map) continue;

            final id = _nullable(item['category_id']);
            final name = _nullable(item['category_name']);

            if (id != null && name != null) {
              names[id.trim()] = name.trim();
            }
          }

          return names;
        } catch (_) {
          // Some Xtream-compatible servers do not
          // implement category actions.
          // Keep the catalog accessible and fall back
          // to embedded metadata.
          _categoryRequests.remove(action);
          return <String, String>{};
        }
      });

  String? _originalCategory(
    Map<String, dynamic> item,
    Map<String, String> names,
    String? fallback,
  ) {
    final id = _nullable(item['category_id'])?.trim();

    if (id != null && names.containsKey(id)) {
      return names[id];
    }

    final embeddedName =
        _nullable(item['category_name']);

    if (embeddedName != null) {
      return embeddedName;
    }

    final ids = item['category_ids'];

    if (ids is List) {
      for (final value in ids) {
        final candidate =
            names[_nullable(value)?.trim()];

        if (candidate != null) {
          return candidate;
        }
      }
    }

    return fallback;
  }

  /// Returns the original category identifier.
  ///
  /// This is deliberately separate from the visible
  /// category name. Child permissions must use the
  /// provider's category ID, not a translated label.
  ///
  /// If a stream has no usable category identity,
  /// null is returned. Child access must then fail
  /// closed until the identity is resolved.
  String? _originalCategoryKey(
    Map<String, dynamic> item,
  ) {
    final direct =
        _nullable(item['category_id'])?.trim();

    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final ids = item['category_ids'];

    if (ids is List && ids.length == 1) {
      final only = _nullable(ids.first)?.trim();

      if (only != null && only.isNotEmpty) {
        return only;
      }
    }

    return null;
  }

  /// Recover category IDs from category-scoped Xtream responses when the
  /// provider omits category_id in its global catalog. Never infer access
  /// from display names or assign ambiguous items to a category.
  Future<Map<String, String>> _recoverCategoryKeys({
    required String categoriesAction,
    required String streamsAction,
    required String idField,
    required List<dynamic> globalItems,
  }) async {
    final missing = <String>{};
    for (final item in globalItems) {
      if (item is! Map) continue;
      final id = _nullable(item[idField]);
      if (id != null && _originalCategoryKey(
        Map<String, dynamic>.from(item),
      ) == null) missing.add(id);
    }
    if (missing.isEmpty) return const {};

    dynamic categories;
    try {
      categories = await _request({'action': categoriesAction});
    } catch (_) {
      return const {};
    }
    if (categories is! List) return const {};

    final ids = <String>{};
    for (final entry in categories) {
      if (entry is! Map) continue;
      final id = _nullable(entry['category_id']);
      if (id != null && id.trim().isNotEmpty) ids.add(id.trim());
    }
    if (ids.isEmpty) return const {};

    final matches = <String, String>{};
    final ambiguous = <String>{};
    // Limit simultaneous requests to avoid overloading the IPTV provider.
    final categoryIds = ids.toList(growable: false);
    for (var offset = 0; offset < categoryIds.length; offset += 4) {
      final batch = categoryIds.skip(offset).take(4);
      await Future.wait(batch.map((categoryId) async {
        dynamic scoped;
        try {
          scoped = await _request({
            'action': streamsAction,
            'category_id': categoryId,
          });
        } catch (_) {
          return;
        }
        if (scoped is! List) return;
        // Some nonstandard providers ignore category_id and return the
        // entire catalog. Such a response is not evidence of membership.
        if (ids.length > 1 && scoped.length >= globalItems.length) return;
        for (final item in scoped) {
          if (item is! Map) continue;
          final id = _nullable(item[idField]);
          if (id == null || !missing.contains(id)) continue;
          final embedded = _originalCategoryKey(
            Map<String, dynamic>.from(item),
          );
          if (embedded != null && embedded != categoryId) continue;
          if (matches.containsKey(id) && matches[id] != categoryId) {
            ambiguous.add(id);
          } else {
            matches[id] = categoryId;
          }
        }
      }));
    }
    for (final id in ambiguous) {
      matches.remove(id);
    }
    return matches;
  }

  static String _normalizeBaseUrl(String value) {
    final parsed = Uri.tryParse(value.trim());

    if (parsed == null ||
        !{'http', 'https'}.contains(parsed.scheme) ||
        parsed.host.isEmpty) {
      throw const FormatException(
        'Ungültige Server-Adresse. '
        'Bitte HTTP(S) inklusive Host eingeben.',
      );
    }

    return value
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');
  }

  Uri _apiUri(Map<String, String> extra) {
    return Uri.parse(
      '$baseUrl/player_api.php',
    ).replace(
      queryParameters: {
        'username': username,
        'password': password,
        ...extra,
      },
    );
  }

  /// A retry is only performed for temporary
  /// transport/server failures.
  ///
  /// Never include API response bodies or
  /// credential-bearing URLs in errors.
  Future<dynamic> _request(
    Map<String, String> params,
  ) async {
    final attempts =
        maxAttempts < 1 ? 1 : maxAttempts;

    for (var attempt = 1;
        attempt <= attempts;
        attempt++) {
      try {
        final response = await _client
            .get(_apiUri(params))
            .timeout(requestTimeout);

        if ({
          429,
          502,
          503,
          504,
        }.contains(response.statusCode)) {
          if (attempt < attempts) {
            await Future<void>.delayed(
              retryDelay,
            );
            continue;
          }

          throw const XtreamConnectionException(
            'Xtream-Server vorübergehend '
            'nicht erreichbar. '
            'Bitte später erneut versuchen.',
          );
        }

        if (response.statusCode == 401 ||
            response.statusCode == 403) {
          throw const XtreamConnectionException(
            'Xtream-Zugang abgelehnt. '
            'Bitte Zugangsdaten prüfen.',
          );
        }

        if (response.statusCode != 200) {
          throw XtreamConnectionException(
            'Xtream-Serverfehler '
            '(HTTP ${response.statusCode}).',
          );
        }

        dynamic decoded;

        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw const FormatException(
            'Ungültige JSON-Antwort '
            'vom Xtream-Server.',
          );
        }

        if (decoded is Map &&
            decoded['user_info'] is Map) {
          final info =
              decoded['user_info'] as Map;

          if (info['auth'] == 0 ||
              info['auth'] == '0' ||
              info['status'] == 'Disabled' ||
              info['status'] == 'Banned') {
            throw const XtreamConnectionException(
              'Xtream-Zugang ist ungültig '
              'oder deaktiviert.',
            );
          }
        }

        if (decoded is Map &&
            decoded['error'] != null) {
          throw const XtreamConnectionException(
            'Xtream-Server meldet '
            'einen API-Fehler.',
          );
        }

        return decoded;
      } on TimeoutException {
        if (attempt == attempts) {
          throw const XtreamConnectionException(
            'Zeitüberschreitung beim '
            'Xtream-Server. '
            'Bitte Verbindung prüfen.',
          );
        }
      } on SocketException {
        if (attempt == attempts) {
          throw const XtreamConnectionException(
            'Keine Netzwerkverbindung '
            'zum Xtream-Server.',
          );
        }
      } on http.ClientException {
        if (attempt == attempts) {
          throw const XtreamConnectionException(
            'Xtream-Netzwerkfehler. '
            'Bitte Verbindung prüfen.',
          );
        }
      }

      await Future<void>.delayed(
        retryDelay,
      );
    }

    throw const XtreamConnectionException(
      'Xtream-Verbindung fehlgeschlagen.',
    );
  }

  Future<List<Channel>> getLiveStreams({
    int? categoryId,
  }) async {
    final data = await _request({
      'action': 'get_live_streams',
      if (categoryId != null)
        'category_id': '$categoryId',
    });

    if (data is! List) {
      throw const FormatException(
        'Unerwartete Live-TV-Antwort.',
      );
    }

    if (data.isEmpty) {
      return <Channel>[];
    }

    final categories = await _categoryNames(
      'get_live_categories',
    );
    final recoveredKeys = await _recoverCategoryKeys(
      categoriesAction: 'get_live_categories',
      streamsAction: 'get_live_streams',
      idField: 'stream_id',
      globalItems: data,
    );

    return data.map((item) {
      final j = item as Map<String, dynamic>;
      final id = '${j['stream_id']}';
      final ext =
          (j['container_extension'] ?? 'ts')
              .toString();

      return Channel(
        id: id,
        name: (j['name'] ??
                'Unbekannter Sender')
            .toString(),
        streamUrl:
            '$baseUrl/live/'
            '${Uri.encodeComponent(username)}/'
            '${Uri.encodeComponent(password)}/'
            '$id.$ext',
        logoUrl: _nullable(j['stream_icon']),
        category: _originalCategory(
          j,
          categories,
          null,
        ),
        epgChannelId:
            _nullable(j['epg_channel_id']),

        // Family-profile authorization metadata.
        sourceKey: sourceKey,
        categoryKey: _originalCategoryKey(j) ?? recoveredKeys[id],
      );
    }).toList();
  }

  Future<List<VodItem>> getVodStreams({
    int? categoryId,
  }) async {
    final data = await _request({
      'action': 'get_vod_streams',
      if (categoryId != null)
        'category_id': '$categoryId',
    });

    if (data is! List) {
      throw const FormatException(
        'Unerwartete VOD-Antwort.',
      );
    }

    if (data.isEmpty) {
      return <VodItem>[];
    }

    final categories = await _categoryNames(
      'get_vod_categories',
    );
    final recoveredKeys = await _recoverCategoryKeys(
      categoriesAction: 'get_vod_categories',
      streamsAction: 'get_vod_streams',
      idField: 'stream_id',
      globalItems: data,
    );

    return data.map((item) {
      final j = item as Map<String, dynamic>;
      final id = '${j['stream_id']}';
      final ext =
          (j['container_extension'] ?? 'mp4')
              .toString();

      return VodItem(
        id: id,
        categoryKey: _originalCategoryKey(j) ?? recoveredKeys[id],
        title: (j['name'] ??
                'Unbekannter Film')
            .toString(),
        plot: _nullable(j['plot']) ?? _nullable(j['description']),
        posterUrl:
            _nullable(j['stream_icon']) ??
            _nullable(j['cover_big']) ??
            _nullable(j['cover']),
        backdropUrl:
            _firstString(j['backdrop_path']),
        genre: _originalCategory(
          j,
          categories,
          _nullable(j['genre']),
        ),
        releaseDate:
            _nullable(j['releasedate']) ??
            _nullable(j['releaseDate']),
        ageRating:
            _nullable(j['rating_age']),
        director: _nullable(j['director']),
        cast: _nullable(j['cast']),
        rating: double.tryParse(
          '${j['rating'] ?? ''}',
        ),
        externalMetadataId:
            _nullable(j['tmdb_id']) ??
            _nullable(j['imdb_id']),
        metadataSource: 'xtream',
        streamUrl:
            '$baseUrl/movie/'
            '${Uri.encodeComponent(username)}/'
            '${Uri.encodeComponent(password)}/'
            '$id.$ext',
        durationSeconds: int.tryParse(
              '${j['duration_secs'] ?? ''}',
            ) ??
            _durationFromText(j['duration']),
      );
    }).toList();
  }

  /// Loads only the series catalog.
  ///
  /// Fetching every series' episodes here would
  /// make large IPTV imports require thousands
  /// of sequential HTTP requests.
  Future<List<Series>> getSeries({
    int? categoryId,
  }) async {
    final data = await _request({
      'action': 'get_series',
      if (categoryId != null)
        'category_id': '$categoryId',
    });

    if (data is! List) {
      throw const FormatException(
        'Unerwartete Serien-Antwort.',
      );
    }

    if (data.isEmpty) {
      return <Series>[];
    }

    final categories = await _categoryNames(
      'get_series_categories',
    );
    final recoveredKeys = await _recoverCategoryKeys(
      categoriesAction: 'get_series_categories',
      streamsAction: 'get_series',
      idField: 'series_id',
      globalItems: data,
    );

    return data.map<Series>((item) {
      if (item is! Map) {
        throw const FormatException(
          'Ungültiger Serieneintrag.',
        );
      }

      final j =
          Map<String, dynamic>.from(item);

      return Series(
        id: '${j['series_id']}',
        categoryKey: _originalCategoryKey(j) ?? recoveredKeys['${j['series_id']}'],
        title: (j['name'] ??
                'Unbekannte Serie')
            .toString(),
        plot: _nullable(j['plot']) ?? _nullable(j['description']),
        posterUrl:
            _nullable(j['cover_big']) ??
            _nullable(j['cover']),
        backdropUrl:
            _firstString(j['backdrop_path']),
        genre: _originalCategory(
          j,
          categories,
          _nullable(j['genre']),
        ),
        releaseDate:
            _nullable(j['releaseDate']) ??
            _nullable(j['release_date']),
        ageRating:
            _nullable(j['rating_age']),
        cast: _nullable(j['cast']),
        director: _nullable(j['director']),
        rating: double.tryParse(
          '${j['rating'] ?? ''}',
        ),
        externalMetadataId:
            _nullable(j['tmdb_id']),
        metadataSource: 'xtream',
        seasons: const [],
      );
    }).toList(growable: false);
  }

  /// Call when the user opens a series.
  /// The caller must update the content provider
  /// with the returned series before rendering
  /// episode playback.
  Future<Series> getSeriesDetails(
    Series catalogSeries,
  ) async {
    final details = await _request({
      'action': 'get_series_info',
      'series_id': catalogSeries.id,
    });

    if (details is! Map) {
      throw const FormatException(
        'Unerwartete Serien-Detailantwort.',
      );
    }

    final info = details['info'] is Map
        ? details['info'] as Map
        : const {};

    // Xtream-compatible servers return seasons either as a map keyed by
    // season number or as a flat list. Ignore malformed records rather than
    // discarding the entire series.
    final episodesRaw = details['episodes'];
    final grouped = <int, List<dynamic>>{};
    if (episodesRaw is Map) {
      for (final entry in episodesRaw.entries) {
        final number = int.tryParse('${entry.key}');
        if (entry.value is! List) continue;
        final seasonNumber = number ?? 1;
        grouped.putIfAbsent(seasonNumber, () => <dynamic>[])
            .addAll(entry.value as List);
      }
    } else if (episodesRaw is List) {
      for (final raw in episodesRaw) {
        if (raw is! Map) continue;
        final number = int.tryParse('${raw['season'] ?? 1}') ?? 1;
        grouped.putIfAbsent(number, () => <dynamic>[]).add(raw);
      }
    }
    final seasons = <Season>[];
    final seasonNumbers = grouped.keys.toList()..sort();
    for (final seasonNumber in seasonNumbers) {
      final episodes = <Episode>[];
      final seen = <String>{};
      final records = grouped[seasonNumber]!;
      for (var i = 0; i < records.length; i++) {
        final raw = records[i];
        if (raw is! Map) continue;
        final id = _nullable(raw['id'] ?? raw['stream_id']);
        if (id == null || !seen.add(id)) continue;
        final episodeInfo = raw['info'] is Map ? raw['info'] as Map : const {};
        final extension = _nullable(raw['container_extension'] ??
                episodeInfo['container_extension']) ?? 'mp4';
        // Never interpolate untrusted extension characters into a URL path.
        final safeExtension = RegExp(r'^[a-zA-Z0-9]{1,8}$')
                .hasMatch(extension) ? extension : 'mp4';
        final number = int.tryParse('${raw['episode_num'] ?? i + 1}') ?? i + 1;
        episodes.add(Episode(
          id: id,
          title: _nullable(raw['title']) ?? _nullable(raw['name']) ??
              'Folge $number',
          number: number,
          streamUrl: '$baseUrl/series/'
              '${Uri.encodeComponent(username)}/'
              '${Uri.encodeComponent(password)}/'
              '${Uri.encodeComponent(id)}.$safeExtension',
          plot: _nullable(episodeInfo['plot']) ??
              _nullable(episodeInfo['description']) ??
              _nullable(raw['plot']) ?? _nullable(raw['description']),
          stillUrl: _nullable(episodeInfo['movie_image']) ??
              _nullable(episodeInfo['cover']) ?? _nullable(raw['movie_image']),
          releaseDate: _nullable(episodeInfo['releasedate']) ??
              _nullable(episodeInfo['releaseDate']) ??
              _nullable(raw['releasedate']),
          durationSeconds: int.tryParse(
                '${episodeInfo['duration_secs'] ?? raw['duration_secs'] ?? ''}',
              ) ?? _durationFromText(episodeInfo['duration'] ?? raw['duration']),
        ));
      }
      episodes.sort((a, b) => a.number.compareTo(b.number));
      if (episodes.isNotEmpty) {
        seasons.add(Season(number: seasonNumber, episodes: episodes));
      }
    }

    final enriched =
        catalogSeries.copyWith(
      plot: _nullable(info['plot']) ?? _nullable(info['description']) ??
          _nullable(details['plot']),
      posterUrl: _nullable(info['cover_big']) ?? _nullable(info['cover']),
      backdropUrl: _firstString(
        info['backdrop_path'],
      ),
      // Preserve the provider folder selected
      // in the series catalog.
      genre: catalogSeries.genre ??
          _nullable(info['genre']),
      releaseDate:
          _nullable(info['releaseDate']),
      ageRating:
          _nullable(info['rating_age']),
      cast: _nullable(info['cast']),
      director: _nullable(info['director']),
      rating: double.tryParse(
        '${info['rating'] ?? ''}',
      ),
      externalMetadataId:
          _nullable(info['tmdb_id']),
    );

    return Series(
      id: enriched.id,
      categoryKey: enriched.categoryKey,
      title: enriched.title,
      plot: enriched.plot,
      posterUrl: enriched.posterUrl,
      backdropUrl: enriched.backdropUrl,
      genre: enriched.genre,
      releaseDate: enriched.releaseDate,
      ageRating: enriched.ageRating,
      cast: enriched.cast,
      director: enriched.director,
      rating: enriched.rating,
      externalMetadataId:
          enriched.externalMetadataId,
      metadataSource:
          enriched.metadataSource,
      metadataProviderId:
          enriched.metadataProviderId,
      metadataAttribution:
          enriched.metadataAttribution,
      metadataLicense:
          enriched.metadataLicense,
      metadataSourceUrl:
          enriched.metadataSourceUrl,
      seasons: seasons,
    );
  }

  static String? _firstString(
    dynamic value,
  ) {
    if (value is List) {
      for (final item in value) {
        final candidate = _nullable(item);

        if (candidate != null) {
          return candidate;
        }
      }
    }

    return _nullable(value);
  }

  static int? _durationFromText(
    dynamic value,
  ) {
    if (value == null) return null;

    final match = RegExp(
      r'^(?:(\d+)\s*[:h]\s*)?(\d+)\s*[:m]\s*(\d+)?',
      caseSensitive: false,
    ).firstMatch(
      value.toString().trim(),
    );

    if (match == null) return null;

    final hours =
        int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes =
        int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds =
        int.tryParse(match.group(3) ?? '') ?? 0;

    return hours * 3600 +
        minutes * 60 +
        seconds;
  }

  static String? _nullable(
    dynamic value,
  ) {
    if (value == null ||
        value.toString().trim().isEmpty) {
      return null;
    }

    return value.toString();
  }

  void close() => _client.close();
}

/// Safe error text: no account details,
/// URLs or server response bodies.
class XtreamConnectionException
    implements Exception {
  final String message;

  const XtreamConnectionException(
    this.message,
  );

  @override
  String toString() => message;
}

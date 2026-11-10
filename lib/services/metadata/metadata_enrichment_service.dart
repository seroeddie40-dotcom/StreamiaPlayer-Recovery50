import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/series.dart';
import '../../models/vod_item.dart';
import 'metadata_catalog.dart';
import 'metadata_record.dart';
import 'episode_metadata_record.dart';
import 'tvmaze_metadata_provider.dart';

/// Applies external metadata only as a fallback. Playlist/Xtream values always
/// win and are never overwritten by an external provider.
class MetadataEnrichmentService {
  final MetadataCatalog catalog;
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, _EpisodeCacheEntry> _episodeCache = {};
  final Duration cacheDuration;

  MetadataEnrichmentService({
    MetadataCatalog? catalog,
    this.cacheDuration = const Duration(hours: 24),
  }) : catalog = catalog ?? MetadataCatalog();

  Future<Series> enrichSeries(Series playlistSeries, {String language = 'en'}) async {
    // Only query a provider if at least one useful field is missing.
    final needsMetadata = _blank(playlistSeries.plot) ||
        _blank(playlistSeries.posterUrl) ||
        _blank(playlistSeries.genre) ||
        _blank(playlistSeries.releaseDate) ||
        playlistSeries.rating == null ||
        playlistSeries.seasons.any((season) => season.episodes.any((episode) =>
          _blank(episode.plot) || _blank(episode.stillUrl) || episode.durationSeconds == null));
    if (!needsMetadata) return playlistSeries;

    final year = _year(playlistSeries.releaseDate);
    final key = 'series|${_normalize(playlistSeries.title)}|${year ?? ''}|$language';
    final now = DateTime.now();
    final cached = _cache[key] ?? await _readPersistent(key);
    if (cached != null && now.difference(cached.createdAt) < cacheDuration) {
      return _enrichEpisodes(_merge(playlistSeries, cached.record), cached.record.providerId);
    }

    final matches = await catalog.search(
      mediaType: 'series',
      title: playlistSeries.title,
      year: year,
      language: language,
    );
    final record = _chooseExactMatch(playlistSeries.title, year, matches);
    if (record == null) return playlistSeries;
    _cache[key] = _CacheEntry(record, now);
    await _writePersistent(key, record, now);
    final merged = _merge(playlistSeries, record);
    return _enrichEpisodes(merged, record.providerId);
  }


  /// Enriches a movie only when playlist/Xtream data is incomplete. Wikidata
  /// contributes text facts only; it does not supply poster artwork here.
  Future<VodItem> enrichMovie(VodItem playlistMovie, {String language = 'en'}) async {
    final needsMetadata = _blank(playlistMovie.plot) ||
        _blank(playlistMovie.genre) || _blank(playlistMovie.releaseDate);
    if (!needsMetadata) return playlistMovie;
    final year = _year(playlistMovie.releaseDate);
    final key = 'movie|${_normalize(playlistMovie.title)}|${year ?? ''}|$language';
    final now = DateTime.now();
    final cached = _cache[key] ?? await _readPersistent(key);
    if (cached != null && now.difference(cached.createdAt) < cacheDuration) {
      return _mergeMovie(playlistMovie, cached.record);
    }
    final matches = await catalog.search(mediaType: 'movie', title: playlistMovie.title,
      year: year, language: language);
    final record = _chooseExactMatch(playlistMovie.title, year, matches);
    if (record == null) return playlistMovie;
    _cache[key] = _CacheEntry(record, now);
    await _writePersistent(key, record, now);
    return _mergeMovie(playlistMovie, record);
  }

  VodItem _mergeMovie(VodItem source, MetadataRecord record) => source.copyWith(
    plot: _prefer(source.plot, record.summary),
    // Never replace a playlist poster with an external image of unverified rights.
    genre: _prefer(source.genre, record.genres.isEmpty ? null : record.genres.join(', ')),
    releaseDate: _prefer(source.releaseDate, record.premiered),
    externalMetadataId: source.externalMetadataId ?? record.providerId,
    metadataSource: source.metadataSource ?? 'playlist+wikidata',
    metadataProviderId: record.providerId,
    metadataAttribution: record.attribution,
    metadataLicense: record.license,
    metadataSourceUrl: record.sourceUrl,
  );

  Future<_CacheEntry?> _readPersistent(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('streamia_metadata_${Uri.encodeComponent(key)}');
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final record = MetadataRecord(
        providerId: '${json['providerId']}', providerName: '${json['providerName']}',
        mediaType: '${json['mediaType']}', title: '${json['title']}',
        summary: json['summary'] as String?, premiered: json['premiered'] as String?,
        genres: (json['genres'] as List? ?? const []).whereType<String>().toList(),
        posterUrl: json['posterUrl'] as String?, backdropUrl: json['backdropUrl'] as String?,
        sourceUrl: json['sourceUrl'] as String?, attribution: '${json['attribution']}',
        license: '${json['license']}', rating: (json['rating'] as num?)?.toDouble());
      final entry = _CacheEntry(record, DateTime.parse('${json['cachedAt']}'));
      _cache[key] = entry;
      return entry;
    } catch (_) { return null; }
  }

  Future<void> _writePersistent(String key, MetadataRecord record, DateTime cachedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('streamia_metadata_${Uri.encodeComponent(key)}', jsonEncode({
        'providerId': record.providerId, 'providerName': record.providerName,
        'mediaType': record.mediaType, 'title': record.title, 'summary': record.summary,
        'premiered': record.premiered, 'genres': record.genres, 'posterUrl': record.posterUrl,
        'backdropUrl': record.backdropUrl, 'sourceUrl': record.sourceUrl,
        'attribution': record.attribution, 'license': record.license,
        'rating': record.rating, 'cachedAt': cachedAt.toIso8601String(),
      }));
    } catch (_) { /* Cache failure must not affect playback. */ }
  }

  Future<Series> _enrichEpisodes(Series series, String providerShowId) async {
    final providers = catalog.providers.whereType<TvMazeMetadataProvider>().toList();
    if (providers.isEmpty) return series;
    final provider = providers.first;
    final needsEpisodes = series.seasons.any((season) => season.episodes.any((episode) =>
      _blank(episode.plot) || _blank(episode.stillUrl) || episode.durationSeconds == null));
    if (!needsEpisodes) return series;
    try {
      final episodeKey = 'tvmaze_episodes_$providerShowId';
      final now = DateTime.now();
      var episodeEntry = _episodeCache[episodeKey];
      if (episodeEntry == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(episodeKey);
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw) as Map;
            final cachedAt = DateTime.parse('${decoded['cachedAt']}');
            final rows = (decoded['episodes'] as List).whereType<Map>();
            final records = rows.map((row) => EpisodeMetadataRecord(
              season: row['season'] as int, number: row['number'] as int,
              title: row['title'] as String?, summary: row['summary'] as String?,
              airDate: row['airDate'] as String?, imageUrl: row['imageUrl'] as String?,
              runtimeMinutes: row['runtimeMinutes'] as int?, providerId: '${row['providerId']}',
              attribution: '${row['attribution']}', license: '${row['license']}',
              sourceUrl: row['sourceUrl'] as String?,)).toList(growable: false);
            episodeEntry = _EpisodeCacheEntry(records, cachedAt);
            _episodeCache[episodeKey] = episodeEntry;
          } catch (_) { episodeEntry = null; }
        }
      }
      if (episodeEntry == null || now.difference(episodeEntry.cachedAt) >= cacheDuration) {
        final records = await provider.fetchEpisodes(providerShowId);
        if (records.isEmpty) return series;
        episodeEntry = _EpisodeCacheEntry(records, now);
        _episodeCache[episodeKey] = episodeEntry;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(episodeKey, jsonEncode({
            'cachedAt': now.toIso8601String(),
            'episodes': records.map((record) => {
              'season': record.season, 'number': record.number, 'title': record.title,
              'summary': record.summary, 'airDate': record.airDate, 'imageUrl': record.imageUrl,
              'runtimeMinutes': record.runtimeMinutes, 'providerId': record.providerId,
              'attribution': record.attribution, 'license': record.license,
              'sourceUrl': record.sourceUrl,
            }).toList(),
          }));
        } catch (_) { /* Episode cache is optional. */ }
      }
      final records = episodeEntry.records;
      if (records.isEmpty) return series;
      final seasons = series.seasons.map((season) {
        final episodes = season.episodes.map((episode) {
          final match = records.where((record) =>
            record.season == season.number && record.number == episode.number).toList();
          if (match.length != 1) return episode;
          final metadata = match.single;
          return episode.copyWith(
            title: _blank(episode.title) ? metadata.title : null,
            plot: _prefer(episode.plot, metadata.summary),
            stillUrl: _prefer(episode.stillUrl, metadata.imageUrl),
            releaseDate: _prefer(episode.releaseDate, metadata.airDate),
            durationSeconds: episode.durationSeconds ??
              (metadata.runtimeMinutes == null ? null : metadata.runtimeMinutes! * 60),
            metadataProviderId: metadata.providerId,
            metadataAttribution: metadata.attribution,
            metadataLicense: metadata.license,
            metadataSourceUrl: metadata.sourceUrl,
          );
        }).toList(growable: false);
        return Season(number: season.number, episodes: episodes);
      }).toList(growable: false);
      return Series(
        id: series.id, title: series.title, plot: series.plot,
        posterUrl: series.posterUrl, backdropUrl: series.backdropUrl,
        genre: series.genre, releaseDate: series.releaseDate,
        ageRating: series.ageRating, cast: series.cast, director: series.director,
        rating: series.rating, externalMetadataId: series.externalMetadataId,
        metadataSource: series.metadataSource, metadataProviderId: series.metadataProviderId,
        metadataAttribution: series.metadataAttribution, metadataLicense: series.metadataLicense,
        metadataSourceUrl: series.metadataSourceUrl, seasons: seasons,
      );
    } catch (_) {
      // External metadata must never interrupt playback or remove playlist data.
      return series;
    }
  }

  MetadataRecord? _chooseExactMatch(String title, String? year, List<MetadataRecord> records) {
    final normalized = _normalize(title);
    final candidates = records.where((r) => _normalize(r.title) == normalized).toList();
    if (candidates.isEmpty) return null;
    if (year != null) {
      final exactYear = candidates.where((r) => (r.premiered ?? '').startsWith(year)).toList();
      if (exactYear.length == 1) return exactYear.single;
      if (exactYear.length > 1) return null;
      // Do not accept a conflicting year when the playlist supplied one.
      if (candidates.any((r) => r.premiered != null)) return null;
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  Series _merge(Series source, MetadataRecord record) => source.copyWith(
    plot: _prefer(source.plot, record.summary),
    posterUrl: _prefer(source.posterUrl, record.posterUrl),
    backdropUrl: _prefer(source.backdropUrl, record.backdropUrl),
    genre: _prefer(source.genre, record.genres.isEmpty ? null : record.genres.join(', ')),
    releaseDate: _prefer(source.releaseDate, record.premiered),
    rating: source.rating ?? record.rating,
    metadataSource: source.metadataSource ?? 'playlist+fallback',
    metadataProviderId: record.providerId,
    metadataAttribution: record.attribution,
    metadataLicense: record.license,
    metadataSourceUrl: record.sourceUrl,
  );

  static String? _prefer(String? original, String? fallback) =>
      _blank(original) ? (_blank(fallback) ? original : fallback) : original;
  static bool _blank(String? value) => value == null || value.trim().isEmpty;
  static String? _year(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(value.trim());
    return match?.group(1);
  }
  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _CacheEntry {
  final MetadataRecord record;
  final DateTime createdAt;
  const _CacheEntry(this.record, this.createdAt);
}

class _EpisodeCacheEntry {
  final List<EpisodeMetadataRecord> records;
  final DateTime cachedAt;
  const _EpisodeCacheEntry(this.records, this.cachedAt);
}

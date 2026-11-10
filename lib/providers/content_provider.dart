import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import '../services/metadata/metadata_enrichment_service.dart';

enum RecentPlaybackType { live, vod, series }

class RecentPlaybackEntry {
  final RecentPlaybackType type;
  final String id;
  final String title;
  final String? imageUrl;
  final Channel? channel;
  final VodItem? vod;
  final Series? series;
  final DateTime viewedAt;
  final String sourceKey;

  const RecentPlaybackEntry({required this.type, required this.id, required this.title,
    this.imageUrl, this.channel, this.vod, this.series, required this.viewedAt, required this.sourceKey});
}

/// An in-memory snapshot only; stream URLs are never written to disk by this cache.
class _ContentLibrarySnapshot {
  final List<Channel> channels;
  final List<VodItem> vod;
  final List<Series> series;
  final String? label;
  const _ContentLibrarySnapshot(this.channels, this.vod, this.series, this.label);
}

class ContentProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  List<VodItem> _vodItems = [];
  List<Series> _series = [];
  bool _isLoaded = false;
  String _sourceKey = 'legacy:default';
  String? _sourceLabel;
  // The active library is held separately; retain at most two inactive ones.
  static const int _maxInactiveCachedLibraries = 2;
  final Map<String, _ContentLibrarySnapshot> _libraryCache = {};
  int _activationGeneration = 0;

  /// A newer activation invalidates any outstanding asynchronous load.
  int beginLibraryActivation() => ++_activationGeneration;
  bool isLibraryActivationCurrent(int generation) => generation == _activationGeneration;

  void _rememberLibrary(String key) {
    if (!_isLoaded) return;
    _libraryCache.remove(key);
    _libraryCache[key] = _ContentLibrarySnapshot(_channels, _vodItems, _series, _sourceLabel);
    while (_libraryCache.length > _maxInactiveCachedLibraries) {
      _libraryCache.remove(_libraryCache.keys.first);
    }
  }

  /// Restores a recently used playlist without a network request.
  bool activateCachedLibrary(String key, {int? activationGeneration}) {
    if (activationGeneration != null && !isLibraryActivationCurrent(activationGeneration)) return false;
    if (_isLoaded && _sourceKey == key) return true;
    final cached = _libraryCache.remove(key);
    if (cached == null) return false;
    _rememberLibrary(_sourceKey);
    _channels = cached.channels;
    _vodItems = cached.vod;
    _series = cached.series;
    _sourceKey = key;
    _sourceLabel = cached.label;
    _isLoaded = true;
    _detachInactiveHistory();
    _resolveCurrentSourceHistory();
    notifyListeners();
    return true;
  }


  String get sourceKey => _sourceKey;
  String? get sourceLabel => _sourceLabel;

  /// Hashes the playlist identity so credentials/URLs are never stored in favorites.
  static String createSourceKey(String identity) =>
      'src:v1:' + sha256.convert(utf8.encode(identity.trim())).toString();
  final MetadataEnrichmentService _metadataEnrichment = MetadataEnrichmentService();
  
  // Recent playback history is kept separately from the loaded content library.
  final List<RecentPlaybackEntry> _recentHistory = [];
  static const String _recentHistoryPrefsKey = 'streamia_recent_playback_v1';
  bool _historyRestoreStarted = false;
  Future<void> _historyWriteQueue = Future<void>.value();

  List<Channel> get channels => _channels;
  List<VodItem> get vodItems => _vodItems;
  List<Series> get series => _series;
  bool get isLoaded => _isLoaded;
  List<RecentPlaybackEntry> get recentHistory => List.unmodifiable(_recentHistory);
  List<RecentPlaybackEntry> get recentLive => _recentHistory.where((e) => e.sourceKey == _sourceKey && e.type == RecentPlaybackType.live).take(10).toList(growable: false);
  List<RecentPlaybackEntry> get recentVod => _recentHistory.where((e) => e.sourceKey == _sourceKey && e.type == RecentPlaybackType.vod).take(10).toList(growable: false);
  List<RecentPlaybackEntry> get recentSeries => _recentHistory.where((e) => e.sourceKey == _sourceKey && e.type == RecentPlaybackType.series).take(10).toList(growable: false);

  void _addRecent(RecentPlaybackEntry entry) {
    _recentHistory.removeWhere((e) => e.type == entry.type && e.id == entry.id && e.sourceKey == entry.sourceKey);
    _recentHistory.insert(0, entry);
    if (_recentHistory.length > 120) _recentHistory.removeLast();
    notifyListeners();
    _persistRecentHistory();
  }

  void _persistRecentHistory() {
    final snapshot = _recentHistory.map((entry) => <String, Object?>{
      'type': entry.type.name,
      'id': entry.id,
      'title': entry.title,
      'imageUrl': entry.imageUrl,
      'sourceKey': entry.sourceKey,
      'viewedAt': entry.viewedAt.toUtc().toIso8601String(),
    }).toList(growable: false);
    _historyWriteQueue = _historyWriteQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_recentHistoryPrefsKey, jsonEncode(snapshot));
      } catch (_) {
        // Local history is best-effort; playback must never depend on storage.
      }
    });
  }

  Future<void> _restoreRecentHistory() async {
    if (_historyRestoreStarted) return;
    _historyRestoreStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recentHistoryPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <RecentPlaybackEntry>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final typeName = value['type'] as String?;
        final id = value['id'] as String?;
        final title = value['title'] as String?;
        final source = value['sourceKey'] as String?;
        final viewed = DateTime.tryParse(value['viewedAt'] as String? ?? '');
        if (id == null || title == null || source == null || viewed == null) continue;
        final type = _findOrNull(RecentPlaybackType.values, (t) => t.name == typeName);
        if (type == null) continue;
        restored.add(RecentPlaybackEntry(type: type, id: id, title: title,
          imageUrl: value['imageUrl'] as String?, viewedAt: viewed, sourceKey: source));
      }
      if (restored.isNotEmpty) {
        _recentHistory
          ..clear()
          ..addAll(restored.take(120));
        _resolveCurrentSourceHistory();
        notifyListeners();
      }
    } catch (_) {
      // Ignore malformed or unavailable local history.
    }
  }

  T? _findOrNull<T>(Iterable<T> items, bool Function(T) matches) {
    for (final item in items) { if (matches(item)) return item; }
    return null;
  }

  /// Release object references from inactive sources. Otherwise history could
  /// keep entire evicted playlists reachable despite the bounded library cache.
  void _detachInactiveHistory() {
    for (var i = 0; i < _recentHistory.length; i++) {
      final entry = _recentHistory[i];
      if (entry.sourceKey == _sourceKey) continue;
      if (entry.channel == null && entry.vod == null && entry.series == null) continue;
      _recentHistory[i] = RecentPlaybackEntry(
        type: entry.type, id: entry.id, title: entry.title,
        imageUrl: entry.imageUrl, viewedAt: entry.viewedAt,
        sourceKey: entry.sourceKey,
      );
    }
  }

  void _resolveCurrentSourceHistory() {
    for (var i = 0; i < _recentHistory.length; i++) {
      final entry = _recentHistory[i];
      if (entry.sourceKey != _sourceKey) continue;
      if (entry.type == RecentPlaybackType.live) {
        final match = _findOrNull(_channels, (item) => item.id == entry.id);
        if (match != null) _recentHistory[i] = RecentPlaybackEntry(type: entry.type, id: entry.id,
          title: match.name, imageUrl: match.logoUrl, channel: match, viewedAt: entry.viewedAt, sourceKey: entry.sourceKey);
      } else if (entry.type == RecentPlaybackType.vod) {
        final match = _findOrNull(_vodItems, (item) => item.id == entry.id);
        if (match != null) _recentHistory[i] = RecentPlaybackEntry(type: entry.type, id: entry.id,
          title: match.title, imageUrl: match.posterUrl ?? match.backdropUrl, vod: match, viewedAt: entry.viewedAt, sourceKey: entry.sourceKey);
      } else {
        final seriesId = entry.id.contains('::') ? entry.id.split('::').first : entry.id;
        final match = _findOrNull(_series, (item) => item.id == seriesId);
        if (match != null) _recentHistory[i] = RecentPlaybackEntry(type: entry.type, id: entry.id,
          title: entry.title, imageUrl: entry.imageUrl ?? match.posterUrl ?? match.backdropUrl, series: match, viewedAt: entry.viewedAt, sourceKey: entry.sourceKey);
      }
    }
  }

  void addVodToHistory(VodItem item) => _addRecent(RecentPlaybackEntry(
    type: RecentPlaybackType.vod, id: item.id, title: item.title,
    imageUrl: item.posterUrl ?? item.backdropUrl, vod: item, viewedAt: DateTime.now(), sourceKey: _sourceKey));

  void addSeriesEpisodeToHistory(Series item, Episode episode, int seasonNumber) => _addRecent(RecentPlaybackEntry(
    type: RecentPlaybackType.series,
    id: '${item.id}::${episode.id}',
    title: '${item.title} · S${seasonNumber} E${episode.number} · ${episode.title}',
    imageUrl: episode.stillUrl ?? item.posterUrl ?? item.backdropUrl,
    series: item,
    viewedAt: DateTime.now(),
    sourceKey: _sourceKey,
  ));

  /// Removes only the selected history category for the currently active source.
  void clearRecentHistory(RecentPlaybackType type) {
    _recentHistory.removeWhere((entry) => entry.sourceKey == _sourceKey && entry.type == type);
    notifyListeners();
    _persistRecentHistory();
  }

  bool replaceLibrary({
    required List<Channel> channels,
    required List<VodItem> vod,
    required List<Series> series,
    String? sourceKey,
    String? sourceLabel,
    int? activationGeneration,
  }) {
    if (activationGeneration != null && !isLibraryActivationCurrent(activationGeneration)) return false;
    if (_sourceKey != sourceKey) _rememberLibrary(_sourceKey);
    if (sourceKey != null) _libraryCache.remove(sourceKey);
    _channels = List.unmodifiable(channels);
    _vodItems = List.unmodifiable(vod);
    _series = List.unmodifiable(series);
    if (sourceKey != null && sourceKey.isNotEmpty) _sourceKey = sourceKey;
    _sourceLabel = sourceLabel;
    _isLoaded = true;
    _restoreRecentHistory();
    _detachInactiveHistory();
    _resolveCurrentSourceHistory();
    notifyListeners();
    return true;
  }

  void setChannels(List<Channel> list) { _channels = list; notifyListeners(); }
  void setVod(List<VodItem> list) { _vodItems = list; notifyListeners(); }
  void setSeries(List<Series> list) { _series = list; notifyListeners(); }

  /// Enriches missing movie text fields from the configured fallback catalog.
  /// Playlist posters, stream URLs and other supplied values remain untouched.
  Future<VodItem?> enrichVodMetadata(String vodId, {String language = 'en'}) async {
    final index = _vodItems.indexWhere((item) => item.id == vodId);
    if (index < 0) return null;
    final original = _vodItems[index];
    final sourceAtStart = _sourceKey;
    final enriched = await _metadataEnrichment.enrichMovie(original, language: language);
    // A network enrichment must not modify another playlist after a switch.
    if (sourceAtStart != _sourceKey) return null;
    final currentIndex = _vodItems.indexWhere((item) => item.id == vodId);
    if (currentIndex < 0 || !identical(_vodItems[currentIndex], original)) return null;
    if (identical(enriched, original)) return original;
    final updated = List<VodItem>.from(_vodItems);
    updated[currentIndex] = enriched;
    _vodItems = List.unmodifiable(updated);
    notifyListeners();
    return enriched;
  }

  /// Enriches only missing series fields; original playlist metadata is kept.
  Future<Series?> enrichSeriesMetadata(String seriesId, {String language = 'en'}) async {
    final index = _series.indexWhere((item) => item.id == seriesId);
    if (index < 0) return null;
    final original = _series[index];
    final sourceAtStart = _sourceKey;
    final enriched = await _metadataEnrichment.enrichSeries(original, language: language);
    if (sourceAtStart != _sourceKey) return null;
    final currentIndex = _series.indexWhere((item) => item.id == seriesId);
    if (currentIndex < 0 || !identical(_series[currentIndex], original)) return null;
    if (identical(enriched, original)) return original;
    final updated = List<Series>.from(_series);
    updated[currentIndex] = enriched;
    _series = List.unmodifiable(updated);
    notifyListeners();
    return enriched;
  }

  void setLoaded(bool value) {
    _isLoaded = value;
    notifyListeners();
  }

  void addToHistory(Channel channel) => _addRecent(RecentPlaybackEntry(
    type: RecentPlaybackType.live, id: channel.id, title: channel.name,
    imageUrl: channel.logoUrl, channel: channel, viewedAt: DateTime.now(), sourceKey: _sourceKey));
}

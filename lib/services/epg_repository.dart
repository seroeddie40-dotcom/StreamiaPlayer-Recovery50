import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show compute;
import '../models/epg_programme.dart';
import 'xmltv_epg_parser.dart';

/// XMLTV data is loaded independently of the decoder. A bounded, shared cache
/// prevents repeated downloads while switching channels or opening overlays.
class EpgRepository {
  /// Shared guide cache for Live TV and the full-screen player. Its HTTP
  /// client must outlive individual screens, so screen disposal is a no-op.
  static final EpgRepository shared = EpgRepository._shared();

  EpgRepository._shared() : _client = http.Client(),
    _ownsClient = false, _isShared = true;

  EpgRepository({http.Client? client}) : _client = client ?? http.Client(),
    _ownsClient = client == null, _isShared = false;
  final bool _isShared;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, List<EpgProgramme>> _cache = {};
  // Per-guide channel index avoids scanning thousands of programmes on every
  // D-pad focus change. Keys retain the original XMLTV channel identifiers.
  final Map<String, Map<String, List<EpgProgramme>>> _channelIndex = {};
  // Normalized lookup is precomputed once per downloaded guide. A null value
  // marks collisions so tolerant matching can never select the wrong channel.
  final Map<String, Map<String, String?>> _normalizedChannelIndex = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<List<EpgProgramme>>> _pending = {};
  final Map<String, DateTime> _lastAttempt = {};
  // Keep only a small number of complete guides: each guide can contain many
  // thousands of programmes even when the downloaded XML is size-limited.
  static const maxCachedGuides = 2;
  // Failed provider URLs must not accumulate forever in a long-lived session.
  static const maxTrackedGuideAttempts = 16;
  static const failedFetchRetryDelay = Duration(seconds: 60);
  static const cacheTtl = Duration(minutes: 30);
  static const maxGuideBytes = 15 * 1024 * 1024;
  // Tiny guides are cheap to parse directly; spawning an isolate for a few
  // programmes adds overhead and can stall isolated Flutter test harnesses.
  static const directParseLimit = 64 * 1024;

  /// Match XMLTV channel identifiers conservatively. First prefer an exact
  /// provider ID. A case/whitespace-insensitive match is only accepted if it
  /// resolves to exactly one XMLTV channel; ambiguous matches stay empty.
  List<EpgProgramme> cached(String url, String channelId) {
    final channels = _channelIndex[url];
    if (channels == null) return const <EpgProgramme>[];
    final exact = channels[channelId];
    if (exact != null) return exact;
    final normalized = channelId.trim().toLowerCase();
    if (normalized.isEmpty) return const <EpgProgramme>[];
    final normalizedIds = _normalizedChannelIndex[url];
    if (normalizedIds == null || !normalizedIds.containsKey(normalized)) {
      return const <EpgProgramme>[];
    }
    final matchedId = normalizedIds[normalized];
    return matchedId == null
        ? const <EpgProgramme>[]
        : channels[matchedId]!;
  }

  Future<List<EpgProgramme>> programmes(String url, String channelId) async {
    if (url.trim().isEmpty || channelId.trim().isEmpty) return [];
    final now = DateTime.now();
    final updated = _fetchedAt[url];
    final lastAttempt = _lastAttempt[url];
    final needsRefresh = updated == null || now.difference(updated) >= cacheTtl;
    final mayRetry = lastAttempt == null ||
        now.difference(lastAttempt) >= failedFetchRetryDelay;
    if (needsRefresh && (mayRetry || _pending.containsKey(url))) {
      try {
        // A failed refresh is throttled, while an already-running refresh is
        // shared across callers. Never discard the last valid cached guide.
        if (!_pending.containsKey(url)) {
          _lastAttempt.remove(url);
          _lastAttempt[url] = now;
          // Insertion order tracks recent attempts. Removing an in-flight
          // timestamp does not cancel its shared Future or the active fetch.
          while (_lastAttempt.length > maxTrackedGuideAttempts) {
            _lastAttempt.remove(_lastAttempt.keys.first);
          }
        }
        await (_pending[url] ??= _fetch(url).whenComplete(() => _pending.remove(url)));
      } catch (_) { /* Retain stale cache when the guide is unreachable. */ }
    }
    return cached(url, channelId);
  }

  Future<List<EpgProgramme>> _fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return const <EpgProgramme>[];
    }

    // A normal Client.get buffers the entire response before its size can be
    // checked. Xtream XMLTV guides may be very large: cap bytes while reading.
    final request = http.Request('GET', uri);
    final response = await _client.send(request)
        .timeout(const Duration(seconds: 15));
    // Even rejected responses own a network stream. Cancel it before returning
    // so an invalid/oversized guide cannot occupy a connection in the shared
    // HTTP client while the user is watching TV.
    final iterator = StreamIterator<List<int>>(response.stream);
    final bytes = BytesBuilder(copy: false);
    try {
      if (response.statusCode != 200 ||
          (response.contentLength != null &&
              response.contentLength! > maxGuideBytes)) {
        return const <EpgProgramme>[];
      }

      // A provider sending tiny chunks indefinitely must not hold a connection.
      // Bound the entire response body, not just idle time between chunks.
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (true) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('XMLTV response exceeded total download time');
        }
        final hasChunk = await iterator.moveNext().timeout(remaining);
        if (!hasChunk) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > maxGuideBytes) {
          // Cancel the HTTP stream immediately; never buffer an oversized guide.
          return const <EpgProgramme>[];
        }
        bytes.add(chunk);
      }
    } finally {
      await iterator.cancel();
    }

    final xml = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    // XML parsing is CPU-heavy for large provider guides. Run it in a
    // background isolate so D-pad input and video overlays remain responsive.
    // The worker receives only XML text, never the authenticated guide URL.
    final programmes = xml.length <= directParseLimit
        ? XmltvEpgParser.parse(xml)
        : await compute(_parseGuideInBackground, xml);
    // Do not overwrite a usable guide with an empty or malformed response.
    if (programmes.isNotEmpty) {
      _cache.remove(url);
      _cache[url] = programmes;
      final byChannel = <String, List<EpgProgramme>>{};
      for (final programme in programmes) {
        (byChannel[programme.channelId] ??= <EpgProgramme>[]).add(programme);
      }
      _channelIndex[url] = byChannel;
      final normalizedIds = <String, String?>{};
      for (final id in byChannel.keys) {
        final normalized = id.trim().toLowerCase();
        if (normalizedIds.containsKey(normalized)) {
          normalizedIds[normalized] = null; // Ambiguous: do not guess.
        } else {
          normalizedIds[normalized] = id;
        }
      }
      _normalizedChannelIndex[url] = normalizedIds;
      _fetchedAt[url] = DateTime.now();
      while (_cache.length > maxCachedGuides) {
        final oldestUrl = _cache.keys.first;
        _cache.remove(oldestUrl);
        _channelIndex.remove(oldestUrl);
        _normalizedChannelIndex.remove(oldestUrl);
        _fetchedAt.remove(oldestUrl);
        _lastAttempt.remove(oldestUrl);
      }
    }
    return programmes;
  }

  void dispose() {
    if (!_isShared && _ownsClient) _client.close();
  }
}

// Must be top-level for Flutter's background-isolate compute API.
List<EpgProgramme> _parseGuideInBackground(String xml) =>
    XmltvEpgParser.parse(xml);

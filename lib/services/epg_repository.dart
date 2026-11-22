import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/epg_programme.dart';
import 'xmltv_epg_parser.dart';

/// XMLTV data is loaded independently of the decoder. A bounded, shared cache
/// prevents repeated downloads while switching channels or opening overlays.
class EpgRepository {
  EpgRepository({http.Client? client}) : _client = client ?? http.Client(),
    _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, List<EpgProgramme>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<List<EpgProgramme>>> _pending = {};
  static const cacheTtl = Duration(minutes: 30);

  List<EpgProgramme> cached(String url, String channelId) =>
    (_cache[url] ?? const <EpgProgramme>[])
      .where((item) => item.channelId == channelId).toList(growable: false);

  Future<List<EpgProgramme>> programmes(String url, String channelId) async {
    if (url.trim().isEmpty || channelId.trim().isEmpty) return [];
    final updated = _fetchedAt[url];
    if (updated == null || DateTime.now().difference(updated) >= cacheTtl) {
      try {
        await (_pending[url] ??= _fetch(url).whenComplete(() => _pending.remove(url)));
      } catch (_) { /* Retain stale cache when the guide is unreachable. */ }
    }
    return cached(url, channelId);
  }

  Future<List<EpgProgramme>> _fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return [];
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 || response.bodyBytes.length > 15 * 1024 * 1024) return [];
    final programmes = XmltvEpgParser.parse(response.body);
    _cache[url] = programmes;
    _fetchedAt[url] = DateTime.now();
    return programmes;
  }

  void dispose() { if (_ownsClient) _client.close(); }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'metadata_provider.dart';
import 'metadata_record.dart';

/// Wikidata fallback for movie text metadata. Wikidata structured data is CC0.
/// This adapter deliberately does not reuse poster files: image licensing is
/// asset-specific and must be checked separately through Wikimedia Commons.
class WikidataMetadataProvider implements MetadataProvider {
  final http.Client _client;
  final Duration timeout;

  WikidataMetadataProvider({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  @override
  String get id => 'wikidata';
  @override
  String get displayName => 'Wikidata';
  @override
  bool supports(String mediaType) => mediaType.toLowerCase() == 'movie' || mediaType.toLowerCase() == 'film';

  @override
  Future<List<MetadataRecord>> search({required String title, String? year, String language = 'en'}) async {
    final query = title.trim();
    if (query.isEmpty) return const [];
    final lang = _supportedLanguage(language);
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': query,
      'language': lang,
      'uselang': lang,
      'type': 'item',
      'limit': '8',
      'format': 'json',
    });
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'StreamiaPlayer/1.0 (metadata lookup)',
    }).timeout(timeout);
    if (response.statusCode == 429) throw const WikidataRateLimitException();
    if (response.statusCode != 200) throw WikidataApiException('Wikidata HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['search'] is! List) return const [];

    final exact = (decoded['search'] as List).whereType<Map>().where((item) =>
      _normalize('${item['label'] ?? ''}') == _normalize(query)).toList();
    if (exact.length != 1) return const [];
    final item = exact.single;
    final description = '${item['description'] ?? ''}'.trim();
    final entityId = '${item['id'] ?? ''}';
    if (!RegExp(r'^Q\d+$').hasMatch(entityId)) return const [];

    final entityUri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities', 'ids': entityId, 'props': 'claims|labels',
      'languages': lang, 'format': 'json',
    });
    final entityResponse = await _client.get(entityUri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'StreamiaPlayer/1.0 (metadata lookup)',
    }).timeout(timeout);
    if (entityResponse.statusCode != 200) return const [];
    final entityJson = jsonDecode(entityResponse.body);
    final entity = entityJson is Map && entityJson['entities'] is Map
        ? (entityJson['entities'] as Map)[entityId] : null;
    if (entity is! Map || entity['claims'] is! Map) return const [];
    final claims = entity['claims'] as Map;
    // Only accept entities explicitly typed as a film (Q11424). This avoids
    // attaching book, song, person or franchise descriptions to a movie.
    final instanceClaims = claims['P31'];
    final isFilm = instanceClaims is List && instanceClaims.any((claim) {
      if (claim is! Map) return false;
      final mainsnak = claim['mainsnak'];
      final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
      final value = datavalue is Map ? datavalue['value'] : null;
      return value is Map && value['id'] == 'Q11424';
    });
    if (!isFilm) return const [];
    final dates = claims['P577'];
    String? releaseDate;
    if (dates is List && dates.isNotEmpty && dates.first is Map) {
      final mainsnak = (dates.first as Map)['mainsnak'];
      final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
      final value = datavalue is Map ? datavalue['value'] : null;
      if (value is Map && value['time'] is String) {
        final match = RegExp(r'\+(\d{4}-\d{2}-\d{2})').firstMatch(value['time'] as String);
        releaseDate = match?.group(1);
      }
    }
    if (year != null && year.isNotEmpty && releaseDate != null && !releaseDate.startsWith(year)) {
      return const [];
    }
    final label = item['label'] is String ? item['label'] as String : query;
    return [MetadataRecord(
      providerId: entityId,
      providerName: displayName,
      mediaType: 'movie',
      title: label,
      summary: description.isEmpty ? null : description,
      premiered: releaseDate,
      sourceUrl: 'https://www.wikidata.org/wiki/$entityId',
      attribution: 'Datenquelle: Wikidata ($entityId)',
      license: 'CC0 (strukturierte Wikidata-Daten)',
    )];
  }

  static String _supportedLanguage(String value) =>
      const {'de', 'en', 'tr', 'ru', 'pl', 'es', 'fr', 'ar'}.contains(value.toLowerCase())
          ? value.toLowerCase() : 'en';
  static String _normalize(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();

  void close() => _client.close();
}

class WikidataRateLimitException implements Exception { const WikidataRateLimitException(); }
class WikidataApiException implements Exception {
  final String message;
  const WikidataApiException(this.message);
  @override
  String toString() => message;
}

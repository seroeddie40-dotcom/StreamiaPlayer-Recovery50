import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/services/metadata/wikidata_metadata_provider.dart';

void main() {
  group('WikidataMetadataProvider', () {
    test('returns metadata only for exact film entities', () async {
      final client = MockClient((request) async {
        if (request.uri.queryParameters['action'] == 'wbsearchentities') {
          return http.Response(jsonEncode({'search': [
            {'id': 'Q123', 'label': 'Example Film', 'description': 'A film description'}
          ]}), 200);
        }
        return http.Response(jsonEncode({'entities': {'Q123': {'claims': {
          'P31': [{'mainsnak': {'datavalue': {'value': {'id': 'Q11424'}}}}],
          'P577': [{'mainsnak': {'datavalue': {'value': {'time': '+2020-01-02T00:00:00Z'}}}}]
        }}}}), 200);
      });
      final provider = WikidataMetadataProvider(client: client);
      final results = await provider.search(title: 'Example Film', year: '2020');
      expect(results, hasLength(1));
      expect(results.single.providerId, 'Q123');
      expect(results.single.premiered, '2020-01-02');
      expect(results.single.license, contains('CC0'));
    });

    test('rejects non-film entities', () async {
      final client = MockClient((request) async {
        if (request.uri.queryParameters['action'] == 'wbsearchentities') {
          return http.Response(jsonEncode({'search': [
            {'id': 'Q456', 'label': 'Example Film', 'description': 'A book'}
          ]}), 200);
        }
        return http.Response(jsonEncode({'entities': {'Q456': {'claims': {
          'P31': [{'mainsnak': {'datavalue': {'value': {'id': 'Q571'}}}}]
        }}}}), 200);
      });
      final provider = WikidataMetadataProvider(client: client);
      expect(await provider.search(title: 'Example Film'), isEmpty);
    });
  });
}

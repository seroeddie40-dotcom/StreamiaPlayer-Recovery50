import 'metadata_provider.dart';
import 'metadata_record.dart';
import 'tvmaze_metadata_provider.dart';
import 'wikidata_metadata_provider.dart';

/// Single entry point used by the app. Add, remove, or replace providers here
/// without coupling screens and content models to a specific vendor.
class MetadataCatalog {
  final List<MetadataProvider> providers;

  MetadataCatalog({List<MetadataProvider>? providers})
      : providers = List.unmodifiable(providers ?? [TvMazeMetadataProvider(), WikidataMetadataProvider()]);

  Future<List<MetadataRecord>> search({
    required String mediaType,
    required String title,
    String? year,
    String language = 'en',
  }) async {
    final matches = <MetadataRecord>[];
    for (final provider in providers.where((p) => p.supports(mediaType))) {
      try {
        matches.addAll(await provider.search(title: title, year: year, language: language));
      } on TvMazeRateLimitException {
        // A provider limit must not break playlist playback or the UI.
        continue;
      } catch (_) {
        // Metadata is optional. Preserve playlist-provided data on failures.
        continue;
      }
    }
    return List.unmodifiable(matches);
  }
}

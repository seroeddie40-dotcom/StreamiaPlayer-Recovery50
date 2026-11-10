import 'metadata_record.dart';

/// Contract for replaceable metadata sources. Implementations must never
/// receive playlist credentials, stream URLs, or user account identifiers.
abstract interface class MetadataProvider {
  String get id;
  String get displayName;
  bool supports(String mediaType);
  Future<List<MetadataRecord>> search({
    required String title,
    String? year,
    String language = 'en',
  });
}

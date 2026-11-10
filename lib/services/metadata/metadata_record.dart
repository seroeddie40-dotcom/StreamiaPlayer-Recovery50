/// Neutral metadata record. Provider-specific IDs and attribution are retained
/// so providers can be replaced without changing the UI or content models.
class MetadataRecord {
  final String providerId;
  final String providerName;
  final String mediaType;
  final String title;
  final String? summary;
  final String? premiered;
  final List<String> genres;
  final String? posterUrl;
  final String? backdropUrl;
  final String? sourceUrl;
  final String attribution;
  final String license;
  final double? rating;

  const MetadataRecord({
    required this.providerId,
    required this.providerName,
    required this.mediaType,
    required this.title,
    this.summary,
    this.premiered,
    this.genres = const [],
    this.posterUrl,
    this.backdropUrl,
    this.sourceUrl,
    required this.attribution,
    required this.license,
    this.rating,
  });
}

/// Provider-neutral episode metadata. Stream URLs are deliberately excluded.
class EpisodeMetadataRecord {
  final int season;
  final int number;
  final String? title;
  final String? summary;
  final String? airDate;
  final String? imageUrl;
  final int? runtimeMinutes;
  final String providerId;
  final String attribution;
  final String license;
  final String? sourceUrl;

  const EpisodeMetadataRecord({
    required this.season,
    required this.number,
    this.title,
    this.summary,
    this.airDate,
    this.imageUrl,
    this.runtimeMinutes,
    required this.providerId,
    required this.attribution,
    required this.license,
    this.sourceUrl,
  });
}

class VodItem {
  final String id;
  final String title;
  final String? plot;
  final String? posterUrl;
  final String? backdropUrl;
  final String? genre;
  final String? releaseDate;
  final String? ageRating;
  final String? director;
  final String? cast;
  final double? rating;
  final String? externalMetadataId;
  final String? metadataSource;
  final String? metadataProviderId;
  final String? metadataAttribution;
  final String? metadataLicense;
  final String? metadataSourceUrl;
  final String streamUrl;
  final int? durationSeconds;

  VodItem({
    required this.id,
    required this.title,
    this.plot,
    this.posterUrl,
    this.backdropUrl,
    this.genre,
    this.releaseDate,
    this.ageRating,
    this.director,
    this.cast,
    this.rating,
    this.externalMetadataId,
    this.metadataSource,
    this.metadataProviderId,
    this.metadataAttribution,
    this.metadataLicense,
    this.metadataSourceUrl,
    required this.streamUrl,
    this.durationSeconds,
  });

  VodItem copyWith({String? plot, String? posterUrl, String? backdropUrl, String? genre,
    String? releaseDate, double? rating, String? externalMetadataId, String? metadataSource,
    String? metadataProviderId, String? metadataAttribution, String? metadataLicense, String? metadataSourceUrl}) {
    return VodItem(id: id, title: title, plot: _keep(plot, this.plot),
      posterUrl: _keep(posterUrl, this.posterUrl), backdropUrl: _keep(backdropUrl, this.backdropUrl),
      genre: _keep(genre, this.genre), releaseDate: _keep(releaseDate, this.releaseDate),
      ageRating: ageRating, director: director, cast: cast, rating: rating ?? this.rating,
      externalMetadataId: externalMetadataId ?? this.externalMetadataId,
      metadataSource: metadataSource ?? this.metadataSource,
      metadataProviderId: metadataProviderId ?? this.metadataProviderId,
      metadataAttribution: metadataAttribution ?? this.metadataAttribution,
      metadataLicense: metadataLicense ?? this.metadataLicense,
      metadataSourceUrl: metadataSourceUrl ?? this.metadataSourceUrl,
      streamUrl: streamUrl, durationSeconds: durationSeconds);
  }

  static String? _keep(String? next, String? current) =>
      next == null || next.trim().isEmpty ? current : next;
}

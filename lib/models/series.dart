class Series {
  final String id;
  final String title;
  final String? plot;
  final String? posterUrl;
  final String? backdropUrl;
  final String? genre;
  final String? releaseDate;
  final String? ageRating;
  final String? cast;
  final String? director;
  final double? rating;
  final String? externalMetadataId;
  final String? metadataSource;
  final String? metadataProviderId;
  final String? metadataAttribution;
  final String? metadataLicense;
  final String? metadataSourceUrl;
  final List<Season> seasons;

  Series({
    required this.id,
    required this.title,
    this.plot,
    this.posterUrl,
    this.backdropUrl,
    this.genre,
    this.releaseDate,
    this.ageRating,
    this.cast,
    this.director,
    this.rating,
    this.externalMetadataId,
    this.metadataSource,
    this.metadataProviderId,
    this.metadataAttribution,
    this.metadataLicense,
    this.metadataSourceUrl,
    required this.seasons,
  });

  Series copyWith({
    String? plot,
    String? posterUrl,
    String? backdropUrl,
    String? genre,
    String? releaseDate,
    String? ageRating,
    String? cast,
    String? director,
    double? rating,
    String? externalMetadataId,
    String? metadataSource,
    String? metadataProviderId,
    String? metadataAttribution,
    String? metadataLicense,
    String? metadataSourceUrl,
  }) => Series(
    id: id,
    title: title,
    plot: plot ?? this.plot,
    posterUrl: posterUrl ?? this.posterUrl,
    backdropUrl: backdropUrl ?? this.backdropUrl,
    genre: genre ?? this.genre,
    releaseDate: releaseDate ?? this.releaseDate,
    ageRating: ageRating ?? this.ageRating,
    cast: cast ?? this.cast,
    director: director ?? this.director,
    rating: rating ?? this.rating,
    externalMetadataId: externalMetadataId ?? this.externalMetadataId,
    metadataSource: metadataSource ?? this.metadataSource,
    metadataProviderId: metadataProviderId ?? this.metadataProviderId,
    metadataAttribution: metadataAttribution ?? this.metadataAttribution,
    metadataLicense: metadataLicense ?? this.metadataLicense,
    metadataSourceUrl: metadataSourceUrl ?? this.metadataSourceUrl,
    seasons: seasons,
  );
}

class Season {
  final int number;
  final List<Episode> episodes;
  Season({required this.number, required this.episodes});
}

class Episode {
  final String id;
  final String title;
  final int number;
  final String? plot;
  final String? stillUrl;
  final String? releaseDate;
  final String streamUrl;
  final int? durationSeconds;
  final String? metadataProviderId;
  final String? metadataAttribution;
  final String? metadataLicense;
  final String? metadataSourceUrl;

  Episode({
    required this.id,
    required this.title,
    required this.number,
    this.plot,
    this.stillUrl,
    this.releaseDate,
    required this.streamUrl,
    this.durationSeconds,
    this.metadataProviderId,
    this.metadataAttribution,
    this.metadataLicense,
    this.metadataSourceUrl,
  });

  Episode copyWith({String? title, String? plot, String? stillUrl, String? releaseDate, int? durationSeconds, String? metadataProviderId, String? metadataAttribution, String? metadataLicense, String? metadataSourceUrl}) => Episode(
    id: id, title: title ?? this.title, number: number, plot: plot ?? this.plot,
    stillUrl: stillUrl ?? this.stillUrl, releaseDate: releaseDate ?? this.releaseDate,
    streamUrl: streamUrl, durationSeconds: durationSeconds ?? this.durationSeconds,
    metadataProviderId: metadataProviderId ?? this.metadataProviderId,
    metadataAttribution: metadataAttribution ?? this.metadataAttribution,
    metadataLicense: metadataLicense ?? this.metadataLicense,
    metadataSourceUrl: metadataSourceUrl ?? this.metadataSourceUrl,
  );
}

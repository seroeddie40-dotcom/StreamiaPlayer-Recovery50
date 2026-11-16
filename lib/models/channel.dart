
class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;

  /// Display name of the channel category.
  /// Existing Live TV screens can continue using it.
  final String? category;

  final String? epgChannelId;

  /// Unique identifier of the playlist containing
  /// this channel. Must match PlaylistProfile.sourceKey.
  String? sourceKey;

  /// Original category identifier from the source.
  ///
  /// Xtream: category_id from the provider.
  /// M3U: the original group-title value.
  ///
  /// Must not be replaced by a translated label.
  String? categoryKey;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.category,
    this.epgChannelId,
    this.sourceKey,
    this.categoryKey,
  });

  /// True when the channel contains enough
  /// source metadata for category authorization.
  bool get hasCategoryIdentity {
    return sourceKey != null &&
        sourceKey!.trim().isNotEmpty &&
        categoryKey != null &&
        categoryKey!.trim().isNotEmpty;
  }

  Channel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? logoUrl,
    String? category,
    String? epgChannelId,
    String? sourceKey,
    String? categoryKey,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      category: category ?? this.category,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      sourceKey: sourceKey ?? this.sourceKey,
      categoryKey: categoryKey ?? this.categoryKey,
    );
  }
}

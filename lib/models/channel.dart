class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? category;
  final String? epgChannelId;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.category,
    this.epgChannelId,
  });
}

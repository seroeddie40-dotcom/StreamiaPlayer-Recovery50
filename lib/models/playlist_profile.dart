class PlaylistProfile {
  final String sourceKey;
  final String displayName;
  final String type;
  final String folderName;
  final bool isVisible;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const PlaylistProfile({
    required this.sourceKey,
    required this.displayName,
    required this.type,
    this.folderName = '',
    this.isVisible = true,
    this.isActive = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  PlaylistProfile copyWith({
    String? displayName,
    String? folderName,
    bool? isVisible,
    bool? isActive,
    int? sortOrder,
  }) => PlaylistProfile(
    sourceKey: sourceKey,
    displayName: displayName ?? this.displayName,
    type: type,
    folderName: folderName ?? this.folderName,
    isVisible: isVisible ?? this.isVisible,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'sourceKey': sourceKey,
    'displayName': displayName,
    'type': type,
    'folderName': folderName,
    'isVisible': isVisible,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory PlaylistProfile.fromJson(Map<String, dynamic> json) => PlaylistProfile(
    sourceKey: json['sourceKey'] as String,
    displayName: json['displayName'] as String? ?? 'Playlist',
    type: json['type'] as String? ?? 'm3u',
    folderName: json['folderName'] as String? ?? '',
    isVisible: json['isVisible'] as bool? ?? true,
    isActive: json['isActive'] as bool? ?? false,
    sortOrder: json['sortOrder'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

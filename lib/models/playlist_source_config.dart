class PlaylistSourceConfig {
  final String sourceKey;
  final String type;
  final String? m3uUrl;
  final String? localFilePath;
  final String? serverUrl;
  final String? username;
  final String? password;

  const PlaylistSourceConfig({
    required this.sourceKey,
    required this.type,
    this.m3uUrl,
    this.localFilePath,
    this.serverUrl,
    this.username,
    this.password,
  });

  Map<String, Object?> toJson() => {
    'sourceKey': sourceKey,
    'type': type,
    'm3uUrl': m3uUrl,
    'localFilePath': localFilePath,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
  };

  factory PlaylistSourceConfig.fromJson(Map<String, dynamic> json) => PlaylistSourceConfig(
    sourceKey: json['sourceKey'] as String,
    type: json['type'] as String,
    m3uUrl: json['m3uUrl'] as String?,
    localFilePath: json['localFilePath'] as String?,
    serverUrl: json['serverUrl'] as String?,
    username: json['username'] as String?,
    password: json['password'] as String?,
  );
}

import '../models/playlist_source_config.dart';

/// Resolves the XMLTV endpoint for the active playlist without persisting
/// credentials in a public URL or starting another video decoder.
class EpgSourceResolver {
  const EpgSourceResolver._();

  static String? resolve(PlaylistSourceConfig? source) {
    if (source == null) return null;
    final configured = source.epgUrl?.trim();
    if (configured != null && configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
          && uri.host.isNotEmpty ? uri.toString() : null;
    }
    if (source.type != 'xtream') return null;
    final server = source.serverUrl?.trim();
    final username = source.username?.trim();
    final password = source.password;
    if (server == null || server.isEmpty || username == null || username.isEmpty ||
        password == null || password.isEmpty) return null;
    final base = Uri.tryParse(server);
    if (base == null || !{'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty) return null;
    // Accept server roots as well as URLs pasted from Xtream API/M3U
    // examples. Never append xmltv.php after player_api.php or get.php.
    final trimmedPath = base.path.replaceFirst(RegExp(r'/+$'), '');
    final pathWithoutApi = trimmedPath.replaceFirst(
      RegExp(r'/(?:player_api|get|xmltv)\.php$', caseSensitive: false),
      '',
    );
    final path = '$pathWithoutApi/xmltv.php';
    return base.replace(path: path, queryParameters: {
      'username': username,
      'password': password,
    }, fragment: '').toString();
  }
}

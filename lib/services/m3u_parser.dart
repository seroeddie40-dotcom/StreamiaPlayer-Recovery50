import 'package:http/http.dart' as http;
import '../models/channel.dart';

/// Lightweight legacy M3U parser. Network loading is bounded so a stalled
/// provider cannot leave the setup flow waiting indefinitely.

class M3uParser {
  static Future<List<Channel>> parseFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Please enter a valid HTTP or HTTPS playlist URL.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('M3U download failed: ${response.statusCode}');
    }
    return parseFromString(response.body);
  }

  static List<Channel> parseFromString(String content) {
    final lines = content.split('\n');
    final channels = <Channel>[];
    String? currentName;
    String? currentLogo;
    String? currentGroup;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        final nameMatch = RegExp(r',(.+)$').firstMatch(line);
        currentName = nameMatch?.group(1)?.trim();
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        currentGroup = groupMatch?.group(1);
      } else if (line.startsWith('http') && currentName != null) {
        channels.add(Channel(
          id: 'ch_${channels.length}',
          name: currentName,
          streamUrl: line,
          logoUrl: currentLogo,
          category: currentGroup,
        ));
        currentName = null;
        currentLogo = null;
        currentGroup = null;
      }
    }
    return channels;
  }
}

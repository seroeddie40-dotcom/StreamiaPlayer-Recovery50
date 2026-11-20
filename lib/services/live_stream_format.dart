/// Stream format selection for Xtream Live TV.
///
/// This utility does not perform network requests and does not log stream URLs
/// (which may contain credentials). A format is only switched for URLs whose
/// path follows the Xtream `/live/<username>/<password>/<id>.<extension>` form.
enum LiveStreamFormat { automatic, hls, mpegTs }

class LiveStreamFormatResolver {
  const LiveStreamFormatResolver._();

  static String resolve(String originalUrl, LiveStreamFormat format) {
    if (format == LiveStreamFormat.automatic) return originalUrl;

    final uri = Uri.tryParse(originalUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return originalUrl;
    }

    final segments = uri.pathSegments;
    if (segments.length < 4 || segments[segments.length - 4] != 'live') {
      return originalUrl;
    }

    final last = segments.last;
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return originalUrl;
    final extension = last.substring(dot + 1).toLowerCase();
    if (extension != 'ts' && extension != 'm3u8') return originalUrl;

    final target = format == LiveStreamFormat.hls ? 'm3u8' : 'ts';
    if (extension == target) return originalUrl;

    final replaced = List<String>.from(segments);
    replaced[replaced.length - 1] = '${last.substring(0, dot)}.$target';
    return uri.replace(pathSegments: replaced).toString();
  }

  static List<String> candidates(String originalUrl, LiveStreamFormat format) {
    final preferred = resolve(originalUrl, format);
    if (format == LiveStreamFormat.automatic || preferred == originalUrl) {
      return <String>[originalUrl];
    }
    // The caller must only attempt the fallback after a genuine open failure.
    return <String>[preferred, originalUrl];
  }
}

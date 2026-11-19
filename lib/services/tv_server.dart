import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class TvServer {
  static HttpServer? _server;
  static String? _pairingToken;
  static DateTime? _expiresAt;
  static String? get pairingToken => _pairingToken;

  static bool _validToken(String? token) {
    return token != null && token == _pairingToken &&
        _expiresAt != null && DateTime.now().isBefore(_expiresAt!);
  }

  static const _headers = <String, String>{
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'referrer-policy': 'no-referrer',
    'x-content-type-options': 'nosniff',
  };

  static Future<String?> start(
    Function(String type, String data1, String data2, String data3) callback,
    String langCode,
  ) async {
    stop();
    final random = Random.secure();
    final token = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
    final router = Router();

    // Übersetzungen für den Webserver
    final isTr = langCode == 'tr';
    final t = {
      'title': isTr ? 'Streamia Player Kurulumu' : 'Streamia Player Setup',
      'desc': isTr ? 'Oynatma listesi verilerinizi buraya girin. Doğrudan TV\'nize gönderilecektir.' : 'Gib hier deine Playlist-Daten ein. Sie werden direkt an deinen TV gesendet.',
      'type': isTr ? 'Tür Seçin' : 'Typ auswählen',
      'typeM3u': isTr ? 'M3U Oynatma Listesi' : 'M3U Playlist',
      'typeXtream': isTr ? 'Xtream Kodları' : 'Xtream Codes',
      'm3uUrl': isTr ? 'M3U URL (veya M3U metni yapıştırın)' : 'M3U URL (oder M3U-Text einfügen)',
      'epgUrl': isTr ? 'EPG URL (İsteğe Bağlı)' : 'EPG URL (Optional)',
      'server': isTr ? 'Sunucu URL\'si' : 'Server URL',
      'user': isTr ? 'Kullanıcı Adı' : 'Benutzername',
      'pass': isTr ? 'Şifre' : 'Passwort',
      'send': isTr ? 'TV\'ye Gönder' : 'An TV senden',
      'success': isTr ? 'Başarıyla Gönderildi!' : 'Erfolgreich gesendet!',
      'successDesc': isTr ? 'Artık bu pencereyi kapatabilirsiniz.' : 'Du kannst dieses Fenster jetzt schließen.',
    };

    router.get('/', (Request request) {
      if (!_validToken(request.url.queryParameters['token'])) {
        return Response(403, body: 'Invalid or expired pairing link', headers: _headers);
      }
      return Response.ok(
        '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Streamia TV Setup</title>
          <style>
            body { font-family: sans-serif; background: #0A0E1A; color: white; padding: 20px; }
            input, textarea, select { width: 100%; padding: 12px; margin: 8px 0; box-sizing: border-box; border-radius: 8px; border: none; }
            button { width: 100%; padding: 15px; background: #00B4FF; color: white; border: none; border-radius: 8px; font-size: 16px; font-weight: bold; margin-top: 20px; }
            h1 { color: #00B4FF; }
            .hidden { display: none; }
          </style>
          <script>
            function toggleFields() {
              var type = document.getElementById('type').value;
              document.getElementById('m3u-fields').style.display = type === 'm3u' ? 'block' : 'none';
              document.getElementById('xtream-fields').style.display = type === 'xtream' ? 'block' : 'none';
            }
          </script>
        </head>
        <body onload="toggleFields()">
          <h1>${t['title']}</h1>
          <p>${t['desc']}</p>
          <form action="/upload" method="POST">
            <input type="hidden" name="token" value="$token">
            <label>${t['type']}</label>
            <select id="type" name="type" onchange="toggleFields()">
              <option value="m3u">${t['typeM3u']}</option>
              <option value="xtream">${t['typeXtream']}</option>
            </select>
            
            <div id="m3u-fields">
              <label>${t['m3uUrl']}</label>
              <textarea name="m3u" rows="4" placeholder="http://example.com/playlist.m3u"></textarea>
              <label>${t['epgUrl']}</label>
              <input type="text" name="epg" placeholder="http://example.com/epg.xml">
            </div>
            
            <div id="xtream-fields" class="hidden">
              <label>${t['server']}</label>
              <input type="text" name="server" placeholder="http://server.com:8080">
              <label>${t['user']}</label>
              <input type="text" name="user">
              <label>${t['pass']}</label>
              <input type="password" name="pass">
            </div>
            
            <button type="submit">${t['send']}</button>
          </form>
        </body>
        </html>
        ''',
        headers: _headers,
      );
    });

    router.post('/upload', (Request request) async {
      const maxBytes = 1024 * 1024;
      final bytes = <int>[];
      Map<String, String> params;
      try {
        await for (final chunk in request.read().timeout(const Duration(seconds: 20))) {
          if (bytes.length + chunk.length > maxBytes) {
            return Response(413, body: 'Request too large');
          }
          bytes.addAll(chunk);
        }
        params = Uri.splitQueryString(utf8.decode(bytes));
      } catch (_) {
        return Response(400, body: 'Invalid request');
      }
      if (!_validToken(params['token']) || params['token'] != token) {
        return Response(403, body: 'Invalid or expired pairing link', headers: _headers);
      }
      final type = params['type'];
      if (type != 'm3u' && type != 'xtream') return Response(400, body: 'Invalid playlist type');
      
      String d1 = '', d2 = '', d3 = '';
      if (type == 'm3u') {
        d1 = params['m3u'] ?? '';
        d2 = params['epg'] ?? '';
      } else {
        d1 = params['server'] ?? '';
        d2 = params['user'] ?? '';
        d3 = params['pass'] ?? '';
      }

      if (d1.trim().isEmpty || (type == 'xtream' && (d2.trim().isEmpty || d3.isEmpty))) {
        return Response(400, body: 'Missing playlist data');
      }
      _pairingToken = null;
      _expiresAt = null;
      callback(type, d1, d2, d3);

      return Response.ok(
        '<html><body style="background:#0A0E1A;color:white;text-align:center;padding-top:50px;"><h1>${t['success']}</h1><p>${t['successDesc']}</p></body></html>',
        headers: _headers,
      );
    });

    try {
      final address = await _findLanAddress();
      if (address == null) return null;
      final previous = _server;
      _server = null;
      await previous?.close(force: true);
      _server = await shelf_io.serve(router.call, address, 8080);
      _pairingToken = token;
      _expiresAt = DateTime.now().add(const Duration(minutes: 10));
      return address.address;
    } catch (e) {
      return null;
    }
  }

  static Future<InternetAddress?> _findLanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    ).timeout(const Duration(seconds: 4));
    final candidates = <MapEntry<int, InternetAddress>>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.startsWith('tun') || name.startsWith('tap') ||
          name.startsWith('rmnet') || name.startsWith('ccmni') ||
          name.startsWith('ppp') || name.startsWith('wg') ||
          name.startsWith('p2p') || name.startsWith('veth')) continue;
      for (final address in interface.addresses) {
        final bytes = address.rawAddress;
        if (address.isLoopback || bytes.length != 4 || bytes[0] == 0 ||
            bytes[0] >= 224 || (bytes[0] == 169 && bytes[1] == 254)) continue;
        final lan = name.startsWith('eth') || name.startsWith('en') ||
            name.startsWith('wlan') || name.startsWith('wifi');
        final private = bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
            (bytes[0] == 192 && bytes[1] == 168);
        if (!lan && !private) continue;
        candidates.add(MapEntry((lan ? 4 : 0) + (private ? 2 : 0), address));
      }
    }
    candidates.sort((a, b) => b.key.compareTo(a.key));
    return candidates.isEmpty ? null : candidates.first.value;
  }

  static void stop() {
    _pairingToken = null;
    _expiresAt = null;
    _server?.close(force: true);
    _server = null;
  }
}

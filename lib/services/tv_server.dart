import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class TvServer {
  static HttpServer? _server;

  static Future<String?> start(
    Function(String type, String data1, String data2, String data3) callback,
    String langCode,
  ) async {
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
        headers: {'content-type': 'text/html'},
      );
    });

    router.post('/upload', (Request request) async {
      final body = await request.readAsString();
      final params = Uri.splitQueryString(body);
      final type = params['type'] ?? 'm3u';
      
      String d1 = '', d2 = '', d3 = '';
      if (type == 'm3u') {
        d1 = params['m3u'] ?? '';
        d2 = params['epg'] ?? '';
      } else {
        d1 = params['server'] ?? '';
        d2 = params['user'] ?? '';
        d3 = params['pass'] ?? '';
      }

      callback(type, d1, d2, d3);

      return Response.ok(
        '<html><body style="background:#0A0E1A;color:white;text-align:center;padding-top:50px;"><h1>${t['success']}</h1><p>${t['successDesc']}</p></body></html>',
        headers: {'content-type': 'text/html'},
      );
    });

    try {
      _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, 8080);
      return _server!.address.address;
    } catch (e) {
      return null;
    }
  }

  static void stop() {
    _server?.close(force: true);
    _server = null;
  }
}

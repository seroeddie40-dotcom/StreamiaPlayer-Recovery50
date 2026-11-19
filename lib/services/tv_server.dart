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

    const translations = <String, Map<String, String>>{
      "en": {
        "title": "Streamia Player Setup",
        "desc": "Enter your playlist details to send them directly to your TV.",
        "type": "Select type",
        "typeM3u": "M3U playlist",
        "typeXtream": "Xtream Codes",
        "m3uUrl": "M3U URL (or paste M3U text)",
        "epgUrl": "EPG URL (optional)",
        "server": "Server URL",
        "user": "Username",
        "pass": "Password",
        "file": "Or select an M3U file (max. 16 MB)",
        "send": "Send to TV",
        "success": "Sent successfully!",
        "successDesc": "You can close this window now.",
        "invalidToken": "Invalid or expired pairing link",
        "invalidSize": "Invalid file size (max. 16 MB)",
        "failed": "Transfer failed",
        "tooLarge": "Request too large",
        "invalidRequest": "Invalid request",
        "invalidType": "Invalid playlist type",
        "missing": "Missing playlist data",
        "received": "Received",
        "timeout": "Transfer timed out",
      },
      "de": {
        "title": "Streamia Player Einrichtung",
        "desc": "Gib deine Playlist-Daten ein, um sie direkt an deinen TV zu senden.",
        "type": "Typ auswählen",
        "typeM3u": "M3U-Playlist",
        "typeXtream": "Xtream Codes",
        "m3uUrl": "M3U-URL (oder M3U-Text einfügen)",
        "epgUrl": "EPG-URL (optional)",
        "server": "Server-URL",
        "user": "Benutzername",
        "pass": "Passwort",
        "file": "Oder M3U-Datei auswählen (max. 16 MB)",
        "send": "An TV senden",
        "success": "Erfolgreich gesendet!",
        "successDesc": "Du kannst dieses Fenster jetzt schließen.",
        "invalidToken": "Ungültiger oder abgelaufener Verbindungslink",
        "invalidSize": "Ungültige Dateigröße (max. 16 MB)",
        "failed": "Übertragung fehlgeschlagen",
        "tooLarge": "Anfrage zu groß",
        "invalidRequest": "Ungültige Anfrage",
        "invalidType": "Ungültiger Playlist-Typ",
        "missing": "Playlist-Daten fehlen",
        "received": "Empfangen",
        "timeout": "Zeitüberschreitung bei der Übertragung",
      },
      "tr": {
        "title": "Streamia Player Kurulumu",
        "desc": "Oynatma listesi bilgilerinizi doğrudan TV’ye göndermek için girin.",
        "type": "Tür seçin",
        "typeM3u": "M3U oynatma listesi",
        "typeXtream": "Xtream Kodları",
        "m3uUrl": "M3U URL (veya M3U metnini yapıştırın)",
        "epgUrl": "EPG URL (isteğe bağlı)",
        "server": "Sunucu URL’si",
        "user": "Kullanıcı adı",
        "pass": "Şifre",
        "file": "Veya M3U dosyası seçin (en fazla 16 MB)",
        "send": "TV’ye gönder",
        "success": "Başarıyla gönderildi!",
        "successDesc": "Artık bu pencereyi kapatabilirsiniz.",
        "invalidToken": "Geçersiz veya süresi dolmuş bağlantı",
        "invalidSize": "Geçersiz dosya boyutu (en fazla 16 MB)",
        "failed": "Aktarım başarısız",
        "tooLarge": "İstek çok büyük",
        "invalidRequest": "Geçersiz istek",
        "invalidType": "Geçersiz liste türü",
        "missing": "Liste bilgileri eksik",
        "received": "Alındı",
        "timeout": "Aktarım zaman aşımına uğradı",
      },
      "ru": {
        "title": "Настройка Streamia Player",
        "desc": "Введите данные плейлиста для отправки на телевизор.",
        "type": "Выберите тип",
        "typeM3u": "Плейлист M3U",
        "typeXtream": "Коды Xtream",
        "m3uUrl": "URL M3U (или вставьте текст M3U)",
        "epgUrl": "URL EPG (необязательно)",
        "server": "URL сервера",
        "user": "Имя пользователя",
        "pass": "Пароль",
        "file": "Или выберите файл M3U (до 16 МБ)",
        "send": "Отправить на ТВ",
        "success": "Успешно отправлено!",
        "successDesc": "Теперь можно закрыть это окно.",
        "invalidToken": "Недействительная или просроченная ссылка",
        "invalidSize": "Недопустимый размер файла (до 16 МБ)",
        "failed": "Ошибка передачи",
        "tooLarge": "Запрос слишком большой",
        "invalidRequest": "Недействительный запрос",
        "invalidType": "Недопустимый тип плейлиста",
        "missing": "Нет данных плейлиста",
        "received": "Получено",
        "timeout": "Время передачи истекло",
      },
      "pl": {
        "title": "Konfiguracja Streamia Player",
        "desc": "Wpisz dane listy, aby przesłać je do telewizora.",
        "type": "Wybierz typ",
        "typeM3u": "Lista M3U",
        "typeXtream": "Kody Xtream",
        "m3uUrl": "URL M3U (lub wklej tekst M3U)",
        "epgUrl": "URL EPG (opcjonalnie)",
        "server": "URL serwera",
        "user": "Nazwa użytkownika",
        "pass": "Hasło",
        "file": "Lub wybierz plik M3U (maks. 16 MB)",
        "send": "Wyślij do TV",
        "success": "Wysłano pomyślnie!",
        "successDesc": "Możesz zamknąć to okno.",
        "invalidToken": "Nieprawidłowy lub wygasły link",
        "invalidSize": "Nieprawidłowy rozmiar pliku (maks. 16 MB)",
        "failed": "Transfer nieudany",
        "tooLarge": "Żądanie jest za duże",
        "invalidRequest": "Nieprawidłowe żądanie",
        "invalidType": "Nieprawidłowy typ listy",
        "missing": "Brak danych listy",
        "received": "Odebrano",
        "timeout": "Przekroczono czas transferu",
      },
      "es": {
        "title": "Configuración de Streamia Player",
        "desc": "Introduce los datos de la lista para enviarlos al televisor.",
        "type": "Seleccionar tipo",
        "typeM3u": "Lista M3U",
        "typeXtream": "Códigos Xtream",
        "m3uUrl": "URL M3U (o pega texto M3U)",
        "epgUrl": "URL EPG (opcional)",
        "server": "URL del servidor",
        "user": "Usuario",
        "pass": "Contraseña",
        "file": "O selecciona un archivo M3U (máx. 16 MB)",
        "send": "Enviar al televisor",
        "success": "¡Enviado correctamente!",
        "successDesc": "Ya puedes cerrar esta ventana.",
        "invalidToken": "Enlace inválido o caducado",
        "invalidSize": "Tamaño de archivo inválido (máx. 16 MB)",
        "failed": "Error de transferencia",
        "tooLarge": "Solicitud demasiado grande",
        "invalidRequest": "Solicitud inválida",
        "invalidType": "Tipo de lista inválido",
        "missing": "Faltan datos de la lista",
        "received": "Recibido",
        "timeout": "Tiempo de transferencia agotado",
      },
      "fr": {
        "title": "Configuration de Streamia Player",
        "desc": "Saisissez les données de la liste pour les envoyer au téléviseur.",
        "type": "Choisir le type",
        "typeM3u": "Liste M3U",
        "typeXtream": "Codes Xtream",
        "m3uUrl": "URL M3U (ou collez le texte M3U)",
        "epgUrl": "URL EPG (facultatif)",
        "server": "URL du serveur",
        "user": "Nom d’utilisateur",
        "pass": "Mot de passe",
        "file": "Ou choisir un fichier M3U (16 Mo max.)",
        "send": "Envoyer au téléviseur",
        "success": "Envoi réussi !",
        "successDesc": "Vous pouvez fermer cette fenêtre.",
        "invalidToken": "Lien invalide ou expiré",
        "invalidSize": "Taille de fichier invalide (16 Mo max.)",
        "failed": "Échec du transfert",
        "tooLarge": "Requête trop volumineuse",
        "invalidRequest": "Requête invalide",
        "invalidType": "Type de liste invalide",
        "missing": "Données de liste manquantes",
        "received": "Reçu",
        "timeout": "Délai de transfert dépassé",
      },
      "ar": {
        "title": "إعداد Streamia Player",
        "desc": "أدخل بيانات قائمة التشغيل لإرسالها مباشرة إلى التلفاز.",
        "type": "اختر النوع",
        "typeM3u": "قائمة M3U",
        "typeXtream": "رموز Xtream",
        "m3uUrl": "رابط M3U (أو الصق نص M3U)",
        "epgUrl": "رابط EPG (اختياري)",
        "server": "رابط الخادم",
        "user": "اسم المستخدم",
        "pass": "كلمة المرور",
        "file": "أو اختر ملف M3U (بحد أقصى 16 ميغابايت)",
        "send": "إرسال إلى التلفاز",
        "success": "تم الإرسال بنجاح!",
        "successDesc": "يمكنك إغلاق هذه النافذة الآن.",
        "invalidToken": "رابط اقتران غير صالح أو منتهي الصلاحية",
        "invalidSize": "حجم ملف غير صالح (بحد أقصى 16 ميغابايت)",
        "failed": "فشل النقل",
        "tooLarge": "الطلب كبير جدًا",
        "invalidRequest": "طلب غير صالح",
        "invalidType": "نوع القائمة غير صالح",
        "missing": "بيانات القائمة ناقصة",
        "received": "تم الاستلام",
        "timeout": "انتهت مهلة النقل",
      },
    };
    final language = translations.containsKey(langCode) ? langCode : "en";
    final t = translations[language]!;
    final direction = language == "ar" ? "rtl" : "ltr";

    router.get('/', (Request request) {
      if (!_validToken(request.url.queryParameters['token'])) {
        return Response(403, body: t['invalidToken']!, headers: _headers);
      }
      return Response.ok(
        '''
        <!DOCTYPE html>
        <html lang="$language" dir="$direction">
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>${t['title']}</title>
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
            async function submitPlaylist(event) {
              var file = document.getElementById('m3u-file').files[0];
              if (document.getElementById('type').value !== 'm3u' || !file) return;
              event.preventDefault();
              var button = document.getElementById('send-button');
              var status = document.getElementById('upload-status');
              if (file.size > 16 * 1024 * 1024 || file.size === 0) {
                status.textContent = ${jsonEncode(t['invalidSize'])}; return;
              }
              button.disabled = true;
              try {
                var response = await fetch('/upload-file', {
                  method: 'POST',
                  headers: {'Content-Type': 'application/octet-stream',
                    'X-Pairing-Token': document.querySelector('[name=token]').value,
                    'X-Epg-Url': encodeURIComponent(document.querySelector('[name=epg]').value)},
                  body: file
                });
                if (!response.ok) throw new Error('HTTP ' + response.status);
                status.textContent = ${jsonEncode(t['success'])};
              } catch (error) {
                status.textContent = ${jsonEncode(t['failed'])}; button.disabled = false;
              }
            }
          </script>
        </head>
        <body onload="toggleFields()">
          <h1>${t['title']}</h1>
          <p>${t['desc']}</p>
          <form action="/upload" method="POST" onsubmit="submitPlaylist(event)">
            <input type="hidden" name="token" value="$token">
            <label>${t['type']}</label>
            <select id="type" name="type" onchange="toggleFields()">
              <option value="m3u">${t['typeM3u']}</option>
              <option value="xtream">${t['typeXtream']}</option>
            </select>
            
            <div id="m3u-fields">
              <label>${t['m3uUrl']}</label>
              <textarea name="m3u" rows="4" placeholder="http://example.com/playlist.m3u"></textarea>
              <label for="m3u-file">${t['file']}</label>
              <input id="m3u-file" type="file" accept=".m3u,.m3u8">
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
            
            <p id="upload-status" role="status"></p>
            <button id="send-button" type="submit">${t['send']}</button>
          </form>
        </body>
        </html>
        ''',
        headers: _headers,
      );
    });

    router.post('/upload-file', (Request request) async {
      final supplied = request.headers['x-pairing-token'];
      if (!_validToken(supplied) || supplied != token) {
        return Response(403, body: t['invalidToken']!);
      }
      const maxBytes = 16 * 1024 * 1024;
      final epgHeader = request.headers['x-epg-url'] ?? '';
      if (epgHeader.length > 8192) return Response(400, body: t['invalidRequest']);
      Directory? directory;
      RandomAccessFile? output;
      var handedOff = false;
      try {
        final epg = Uri.decodeComponent(epgHeader);
        final temp = await Directory.systemTemp.createTemp('streamia_upload_');
        directory = temp;
        final file = File('${temp.path}/playlist.m3u');
        output = await file.open(mode: FileMode.write);
        var count = 0;
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        await for (final chunk in request.read().timeout(const Duration(seconds: 15))) {
          if (DateTime.now().isAfter(deadline)) return Response(408, body: t['timeout']);
          count += chunk.length;
          if (count > maxBytes) return Response(413, body: t['tooLarge']);
          await output.writeFrom(chunk);
        }
        await output.close();
        output = null;
        if (count == 0) return Response(400, body: t['invalidSize']);
        if (!_validToken(supplied) || supplied != token) return Response(403, body: t['invalidToken']);
        _pairingToken = null;
        _expiresAt = null;
        // The receiver owns the temporary directory after handoff.
        callback('m3u_file', file.path, epg, '');
        handedOff = true;
        return Response.ok(t['received']!, headers: {'cache-control': 'no-store'});
      } catch (_) {
        return Response(400, body: t['failed']!);
      } finally {
        try { await output?.close(); } catch (_) {}
        if (!handedOff) {
          try { await directory?.delete(recursive: true); } catch (_) {}
        }
      }
    });

    router.post('/upload', (Request request) async {
      const maxBytes = 1024 * 1024;
      final bytes = <int>[];
      Map<String, String> params;
      try {
        await for (final chunk in request.read().timeout(const Duration(seconds: 20))) {
          if (bytes.length + chunk.length > maxBytes) {
            return Response(413, body: t['tooLarge']!);
          }
          bytes.addAll(chunk);
        }
        params = Uri.splitQueryString(utf8.decode(bytes));
      } catch (_) {
        return Response(400, body: t['invalidRequest']!);
      }
      if (!_validToken(params['token']) || params['token'] != token) {
        return Response(403, body: t['invalidToken']!, headers: _headers);
      }
      final type = params['type'];
      if (type != 'm3u' && type != 'xtream') return Response(400, body: t['invalidType']!);
      
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
        return Response(400, body: t['missing']!);
      }
      _pairingToken = null;
      _expiresAt = null;
      callback(type, d1, d2, d3);

      return Response.ok(
        '<html lang="$language" dir="$direction"><body style="background:#0A0E1A;color:white;text-align:center;padding-top:50px;"><h1>${t['success']}</h1><p>${t['successDesc']}</p></body></html>',
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

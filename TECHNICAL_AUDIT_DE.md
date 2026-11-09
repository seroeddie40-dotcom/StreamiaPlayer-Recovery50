# Streamia Player – technischer Prüfbericht

Stand: 07.11.2026
Geprüfte Grundlage: hochgeladene GitHub-ZIP `streamiaplayer-main.zip`

## Ergebnis in einem Satz
Das Repository ist ein Flutter-UI-/Prototyp mit Teilen einer Player-Implementierung. Es ist noch keine geschlossene, produktionsreife App. Es fehlen Backend, echte Authentifizierung, sichere Playlist-Speicherung, echte Zahlungen und mehrere vollständige Datenflüsse.

## In dieser Revision angepasst
- M3U-Parser: prüft jetzt den M3U-Kopf, unterstützt CRLF, liest `tvg-id`, `tvg-logo`, `group-title`, akzeptiert HTTP(S)/RTSP/RTMP-Stream-URLs und ersetzt die Bibliothek atomar erst nach erfolgreichem Parsing.
- Xtream: Server-URL-Validierung, URI-sicheres Query-Encoding, Timeout-/HTTP-/Auth-Fehlerbehandlung, Live-TV- und VOD-Laden sowie Serien-/Folgenabruf ergänzt.
- Setup: Xtream-Eingabe-Button und QR-Eingabe verwenden nun den tatsächlichen Ladeablauf statt einer reinen Statusmeldung.
- Test: den nicht passenden Flutter-Counter-Template-Test durch M3U-Parser-Tests ersetzt.
- Build-Umgebung: maschinenlokale `android/local.properties` aus dem ZIP entfernt; `assets/images/` als deklarierter Asset-Ordner ergänzt; unnötigen Dependency-Override entfernt.

## Noch offen – zwingend vor einer öffentlichen Veröffentlichung

### 1. Backend / Benutzer / Geräte
Im ZIP ist keine Supabase-Integration enthalten:
- keine Supabase-Initialisierung oder Projektkonfiguration
- keine Datenbankmigrationen oder RLS-Regeln
- keine echte E-Mail-/Passwort-/Social-Authentifizierung
- keine Gerätebindung, Sitzungsverwaltung oder serverseitige Gerätebegrenzung
- kein sicherer QR-Pairing-Endpunkt
- keine Cloud-Synchronisierung von Favoriten, Verlauf oder Playlists

`AuthProvider` ist derzeit eine lokale MAC-Adress-Demo. Eine MAC-Adresse ist keine verlässliche Geräteidentität und kein Login. Die Login-Ansicht enthält zudem einen Continue-Button ohne Authentifizierungsprüfung.

### 2. Zahlungen / Premium
Die Paywall ist nur eine Preis-Auswahl. Sie startet keine Zahlung und prüft keine Zahlung. Keine Provider-API, Webhooks, Signaturprüfung, Entitlements oder Aboverwaltung vorhanden. Keine Premium-Funktion darf deshalb als bezahlt/freigeschaltet gelten.
Erforderlich: Providerentscheidung und schriftliche Freigabe des Geschäftsmodells, serverseitige Checkout-Erstellung, signierte Webhooks, Idempotenz, Supabase-Entitlements, Kündigung/Erstattung/Verlängerung und Google-Play-Billing-Konformität.

### 3. Playlist-Daten und Sicherheit
- M3U- und Xtream-Zugangsdaten werden nicht sicher als Playlist-Profil gespeichert oder wiederhergestellt.
- Xtream-URLs enthalten Zugangsdaten im Pfad; Logs, Fehlerberichte und Verlauf dürfen solche URLs niemals unredigiert speichern.
- Lokaler TV-Webserver lauscht auf allen IPv4-Schnittstellen und hat keinen Pairing-Token, keine TLS-Verschlüsselung und keinen CSRF-/Replay-Schutz. Nicht in öffentlichen Netzwerken betreiben.
- Android `usesCleartextTraffic=true` erlaubt unverschlüsseltes HTTP. Vor Release möglichst HTTPS erzwingen oder gezielte Ausnahmen definieren.
- Der M3U-Standard liefert keine verlässliche Film-/Serien-/Staffelstruktur. Die Einordnung von M3U-Einträgen bleibt heuristisch. Xtream-Metadaten sind hierfür vorzuziehen.

### 4. Player und Medienfunktionen
- Aufnahme-Service erstellt eine Datei, hängt aber den Stream nicht an diese Datei an. Die angezeigte Aufnahmefunktion nimmt daher aktuell keinen tatsächlichen Stream auf.
- Downloads benötigen Fehleranzeige, Abbruch, Dateinamen-Säuberung, Speicher-/Formatprüfung und Rechteprüfung.
- EPG-URL und EPG-Datei werden angenommen, aber nicht in eine Programmtabelle integriert.
- Catch-up, Timeshift, Multi-Screen, Untertitel-/Audioauswahl, Favoriten, Suchindex und Offline-Wiedergabe sind nicht als vollständige End-to-End-Funktionen nachgewiesen.
- Serienabruf ruft `get_series_info` je Serie ab; bei sehr großen Bibliotheken kann der erste Import lange dauern und sollte später paginiert/gestaffelt werden.

### 5. Plattform und Tests
- Das Repository enthält keine verlässliche CI-Ausgabe und keine erfolgreiche Build-/Testausgabe.
- In der aktuellen Arbeitsumgebung sind Flutter und Dart SDK nicht installiert. `flutter pub get`, `flutter analyze`, `flutter test` und Android-Build konnten hier nicht ausgeführt werden.
- Android-TV-Fokusnavigation, D-Pad-Tests, reale Geräte-/Codec-Kompatibilität und Android-Release-Signierung müssen auf Zielgeräten getestet werden.
- `android/local.properties` wurde entfernt, weil der enthaltene Windows-Pfad nur auf dem ursprünglichen Rechner gilt. Android Studio/Flutter erzeugt diese Datei lokal neu.

## Nächste notwendigen Informationen für eine wirklich geschlossene Version
1. Supabase-Projekt-URL und anon key (niemals service-role key in die App oder ZIP legen).
2. Gewünschte Login-Methode: E-Mail/Passwort, Google, QR-Gerätekopplung oder Kombination.
3. Zahlungsanbieter und dessen bestätigte API-/Webhook-Unterlagen. Keine geheimen API-Schlüssel in Chat oder Quellcode senden.
4. Soll eine Playlist nur lokal auf dem Gerät bleiben oder über das Benutzerkonto auf mehrere Geräte synchronisieren?
5. Zielplattformen für Release: Android TV, Android Smartphone/Tablet, Web-Portal.

## Rechtlicher / Produkt-Hinweis
Streamia sollte ausschließlich ein Medienplayer bleiben. Nutzer müssen selbst für die Rechtmäßigkeit ihrer hinzugefügten Streams und Playlists verantwortlich sein. Die App sollte keine Sender, Filme oder Serien bündeln oder bereitstellen.

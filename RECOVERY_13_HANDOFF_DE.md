# Streamia Player – Übergabe Recovery 13

## Kanonischer Stand
Diese ZIP ist die aktuelle Arbeitsgrundlage. Recovery 12 bleibt als Rückfallversion erhalten.

## Neu in Recovery 13
- Favoritenübersicht in Einstellungen: Sender / Filme / Serien.
- Einzelnes Entfernen und Aktualisieren der Favoriten.
- Xtream-Fingerprint ohne Passwort.
- M3U-Fingerprint ohne Query-Tokens und ohne volatile Bild-URLs.

## Nächste Arbeitsschritte
1. Flutter SDK auf Windows nutzen: `flutter pub get`, `flutter analyze`, `flutter test`.
2. Fehler aus Analyse und Tests beheben.
3. Supabase-Migration `202611080003_account_favorites_sync.sql` zuerst in einem Testprojekt ausführen.
4. RLS, Upsert, Löschen und Import/Export testen.
5. Android APK erstellen und Gerätewechsel mit demselben Konto prüfen.
6. Favoriten nach erneutem Einbinden einer M3U- bzw. Xtream-Quelle anhand der Quellkennung testen.

## Sicherheits- und Funktionsgrenzen
- Keine Playlist-Passwörter, Stream-URLs oder Medieninhalte in Favoriten-Backups.
- Favoriten-Cloudspeicherung ist erst nach Anwendung der Supabase-Migration nutzbar.
- Eine M3U-Quelle kann sich so stark ändern, dass ein automatischer Abgleich nicht garantiert werden kann.
- Noch kein Flutter-Build und kein Live-Datenbanktest in der Erstellungsumgebung.

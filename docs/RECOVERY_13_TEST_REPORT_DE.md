# Streamia Player – Recovery 13

## Neuer Arbeitsblock: Favoritenbibliothek und Quellidentität

### Umgesetzt
- Neue Seite „Meine Favoriten“ mit getrennten Ansichten für Sender, Filme und Serien.
- Favoriten werden kontobasiert aus Supabase geladen.
- Einzelne Favoriten können aus der Cloud-Liste entfernt werden.
- Aktualisieren per Refresh-Schaltfläche und Pull-to-refresh.
- Leere Zustände und Lade-/Fehlerzustände ergänzt.
- Einstellungen öffnen nun sowohl die Favoritenbibliothek als auch die separate Backup-/Importseite.
- Xtream-Quellfingerprint verwendet Serveradresse und Benutzername, nicht mehr das Passwort.
- M3U-Quellfingerprint basiert auf stabilen Inhaltskennungen und Host statt Cover-/Logo-URLs.
- M3U-Streampfad-Fingerprints verwenden nur Host und letzten Pfadbestandteil; Query-Tokens und potenzielle Benutzer-/Passwortsegmente werden ausgeschlossen.
- Favoriten-Backups enthalten weiterhin keine Stream-URLs, Playlist-Zugangsdaten oder Mediendateien.

### Statische Prüfungen
- 8 Sprachdateien erfolgreich als JSON gelesen.
- `pubspec.yaml` erfolgreich als YAML gelesen.
- Alle relativen Dart-Importziele vorhanden.
- Navigation zur neuen Favoritenbibliothek vorhanden.
- Sender-, Film- und Serienkategorien in der Favoritenbibliothek vorhanden.
- Xtream-Fingerprint enthält kein Passwort.
- M3U-Fingerprint liest keine Query-Parameter.
- Backup-Format und Import-/Exportmethoden vorhanden.

### Nicht ausgeführt
- Flutter analyze / flutter test / APK-Build: Flutter- und Dart-SDK in dieser Umgebung nicht installiert.
- Supabase-Migration / RLS-Liveprüfung: nicht ausgeführt.
- Realer Gerätewechseltest: nicht ausgeführt.

### Voraussetzungen für Cloudbetrieb
Die Migration `supabase/migrations/202611080003_account_favorites_sync.sql` muss in Supabase angewendet werden. Danach sind Cloud-Lesen, Upsert, Löschen, Export und Import auf echten Android-Geräten zu testen.

### Wichtiger Hinweis zur M3U-Kompatibilität
M3U-Playlists besitzen kein einheitliches Schema für stabile Medien-IDs. Bei Anbietern, die IDs oder URL-Strukturen ändern, kann die Wiedererkennung trotz Fingerprint nicht garantiert werden. Xtream-IDs sind in der Regel stabiler. Das Backup dient als zusätzliche Sicherung; die passende Playlist muss auf dem neuen Gerät erneut eingebunden werden.

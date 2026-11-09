# Favoriten-Synchronisierung – Recovery 12

## Umgesetzt
- Favoriten-Schaltflächen in Live-TV-, Film- und Serienkarten sowie in Film-/Seriendetails.
- Speicherung je angemeldetem Supabase-Konto in `public.favorites`.
- Trennung nach `live`, `vod` und `series`.
- Quelle wird als SHA-256-Fingerprint gespeichert; Playlist-URL, Benutzername, Passwort und Stream-URL werden nicht in Favoriten geschrieben.
- M3U-Inhaltskennungen sind deterministisch statt positionsabhängig; Xtream-Inhaltskennungen verwenden die Provider-Stream-ID.
- Favoriten werden beim Anzeigen der jeweiligen Karte aus dem Konto geladen; dadurch erscheinen sie nach Anmeldung und erneuter Playlist-Einbindung auf weiteren Geräten.
- Backup-Export/Import bleibt versioniert und verwendet Upsert/Deduplizierung.
- Migration ergänzt Update-RLS-Policy für Upsert und bereinigt Alt-Duplikate vor dem Unique-Index.

## Voraussetzungen
1. Supabase-Migration `202611080003_account_favorites_sync.sql` muss nach den vorherigen Migrationen ausgeführt sein.
2. Nutzer müssen mit demselben Streamia-Konto angemeldet sein.
3. Für die automatische Wiedererkennung muss dieselbe Playlist-Quelle erneut eingebunden werden. Bei M3U wird die Quelle über einen Fingerprint der Playlist-Metadaten identifiziert; bei Xtream über Server/Benutzer/Zugangsdaten (nur gehasht).

## Grenzen / bewusstes Verhalten
- Streamia überträgt keine Playlist-Zugangsdaten und keine Stream-URLs.
- Wenn ein Playlist-Anbieter Einträge vollständig umbenennt, IDs ändert oder eine andere Quelle verwendet wird, kann eine automatische Zuordnung nicht garantiert werden. Das JSON-Backup bleibt als manuelle Sicherung.
- M3U-Formate besitzen keine standardisierte, dauerhafte Inhalts-ID. Der Fingerprint aus Metadaten kann bei stark veränderten Playlists eine neue Quellenkennung ergeben.
- Favoriten werden nicht automatisch auf eine andere Playlist eines anderen Anbieters gemappt; das wäre ohne sichere Inhaltsidentität fehleranfällig.

## Noch zu testen
- Supabase-Migration in einer Testdatenbank (nicht live angewendet).
- Anlegen/Löschen mit RLS über zwei Testkonten.
- Android-Import/Export und Wiederanmeldung auf Zweitgerät.
- Flutter Analyze und APK-Build (Flutter SDK in der Arbeitsumgebung nicht verfügbar).

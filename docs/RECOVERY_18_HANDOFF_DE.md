# Recovery 18 – Übergabe

## Neu
Offline-Warteschlange für Wiedergabefortschritt in `lib/services/watch_progress_service.dart`. Bei fehlgeschlagenem Cloud-Upsert wird die aktuellste Position je Quelle, Inhalts-ID und Typ lokal im Konto-spezifischen SharedPreferences-Schlüssel gehalten (maximal 100 Einträge). `flushPending()` versucht beim nächsten Lese-/Speichervorgang erneut die Übertragung an Supabase.

## Datenschutz
Es werden keine Playlist-URLs, Stream-URLs, Benutzernamen oder Passwörter in der Queue abgelegt. Die Queue ist nach Supabase-Benutzer-ID getrennt.

## Wichtig
Das ist Best-Effort-Offline-Sync, keine garantierte Hintergrundsynchronisierung: Ohne erneutes Öffnen/Lesen/Speichern durch die App kann die Queue bis zum nächsten App-Aufruf lokal bleiben. Netzwerk-Reconnect und App-Neustart müssen auf echten Android-Geräten getestet werden. Flutter/Dart SDK ist in der Arbeitsumgebung nicht verfügbar; kein APK-Build oder Flutter-Test behauptet. Supabase-Migrationen wurden nicht live ausgeführt.

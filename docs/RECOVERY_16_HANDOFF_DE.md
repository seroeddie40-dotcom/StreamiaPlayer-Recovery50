# Recovery 16 – Übergabe

## Änderung
Der Player reagiert jetzt auf grundlegende Android-TV-/D-pad-Tasten: OK/Enter/Select/Leertaste für Play/Pause, links/rechts für 10-Sekunden-Sprünge (bei VOD/Serien), hoch/runter zum Einblenden der Steuerung. Überlappende Fortschrittsspeicherungen werden unterdrückt.

## Grenzen
Dies ist keine vollständige App-weite Android-TV-Fokusnavigation. Senderlisten, Menüs, Dialoge und Einstellungen müssen auf echter TV-Hardware separat geprüft und optimiert werden.

## Weiterhin offen
- `202611080004_watch_progress_sync.sql` in Supabase ausführen.
- Flutter Analyze/Tests und APK-Build mit lokal installiertem Flutter SDK.
- Android-TV-Fernbedienung auf realer Hardware testen.
- Offline-Warteschlange für Wiedergabefortschritt ergänzen.

## Validierung
JSON-Sprachdateien, YAML, relative Dart-Imports, Migration-Invarianten und ZIP-Integrität werden statisch geprüft. In dieser Arbeitsumgebung sind Flutter/Dart SDK und psql nicht verfügbar; daher keine Behauptung eines Builds, Flutter-Tests oder SQL-Live-Laufs.

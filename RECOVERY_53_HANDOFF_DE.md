# Streamia Player – Recovery 53 (09.11.2026)

Basis: Recovery 52.

## Änderungen
- Verlaufseinträge inaktiver Playlist-Quellen behalten ihre Metadaten, lösen aber Objektverweise auf Kanäle/Filme/Serien. Damit kann der begrenzte Bibliothekscache alte Quellen tatsächlich freigeben.
- Beim Rückwechsel werden Verlaufseinträge aus der aktuell geladenen Quelle wieder zugeordnet.
- Asynchrone Metadaten-Anreicherung für VOD und Serien verwirft Ergebnisse nach Quellenwechsel oder wenn der ursprüngliche Datensatz inzwischen ersetzt wurde.
- Playlist-Navigation erhält eine höhere maximale Listenfläche (Smartphone 260, größere Geräte 320), damit mehrere Quellen besser erreichbar sind.
- Zwei Tests zur Quellenisolierung des Verlaufs hinzugefügt.

## Prüfstatus
ZIP-Integrität und statische Strukturprüfung durchgeführt. Flutter/Dart SDK nicht vorhanden: kein flutter analyze/test/build und keine Hardwaretests.

## Weiter offen
Android-TV-Fokus und Fernbedienung auf Hardware, 8-Sprachen-Tastatur, Netzwerkfehler/Timeouts, APK-Erstellung und End-to-End-Tests.

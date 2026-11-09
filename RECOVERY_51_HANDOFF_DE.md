# Streamia Player – Recovery 51 (09.11.2026)

## Neu in diesem Arbeitsblock
- `ContentProvider`: begrenzter In-Memory-Cache für bis zu drei Playlist-Bibliotheken (einschließlich aktiver Quelle), zuletzt verwendete Quellen können ohne erneuten Netzwerkabruf aktiviert werden.
- `PlaylistSwitchService`: Cache-Schnellwechsel; bisherige Bibliothek bleibt bei fehlgeschlagenem Abruf erhalten.
- Aktivierungs-Generation verhindert, dass ein verspäteter M3U-/Xtream-Ladevorgang eine neuere Quellenauswahl überschreibt.
- `PlaylistParser` übernimmt den Generationstoken beim Einspielen der Bibliothek.
- Drei zusätzliche Flutter-Tests für Cache-Wiederherstellung, veraltete Ladevorgänge und Cache-Grenze.

## Grenzen / nächste Schritte
- Cache ist nur im Arbeitsspeicher und nach App-Neustart leer. Keine Offline-Garantie für noch nicht geladene Quellen.
- Bis zu drei Quellen im Cache können bei großen Listen erhöhten RAM-Bedarf verursachen; Performance-Messung und ggf. speicherabhängige Begrenzung auf Android TV notwendig.
- Ein laufender `setActive`-Speichervorgang kann bei sehr schnellem mehrfachen Wechsel noch eine ältere Profilmarkierung schreiben; das ist separat abzusichern.
- Kein Flutter-/Dart-SDK, daher Tests, Analyse, APK-Build und Hardwareprüfung **nicht ausgeführt**. Statische Prüfungen sind kein Ersatz dafür.

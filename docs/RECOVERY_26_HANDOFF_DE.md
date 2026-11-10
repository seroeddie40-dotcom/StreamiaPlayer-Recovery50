# Streamia Player – Recovery 26 Übergabe

## Stand
Recovery 26 baut vollständig auf Recovery 25 auf.

## Änderungen
- PlayerScreen: untere kontextabhängige Mediensteuerung ergänzt.
- VOD/Serien: 10-Sekunden-Sprung zurück/vor.
- Audiospuren: Auswahl der vom Player gemeldeten Audio-Tracks.
- Untertitel: Auswahl der gemeldeten Untertitel-Tracks sowie „Aus“.
- Bildformat: Umschalten zwischen contain, cover und fill.

## Bewusste Grenzen
- Live-TV bietet keine Zeit-Sprungsteuerung, da viele Live-Streams kein seekbares Zeitfenster bereitstellen.
- Audio-/Untertiteloptionen hängen von den Metadaten und Fähigkeiten des jeweiligen Streams ab.
- Die Track-Auswahl muss mit dem installierten media_kit-Build verifiziert werden. In dieser Umgebung sind Flutter und Dart SDK nicht verfügbar, daher wurde kein Flutter-Build behauptet.
- Noch nicht umgesetzt: separate externe Untertiteldateien, Audio-Delay, individuelle Zoom-/Pan-Steuerung und persistente Bildformatpräferenz.

## Prüfungen
Statische Prüfung der geänderten Dateien, JSON-Sprachdateien, pubspec YAML, relativen Imports und ZIP-Integrität. Geräte- und Live-Stream-Tests ausstehend.

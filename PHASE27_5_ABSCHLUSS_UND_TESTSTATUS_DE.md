# Phase 27.5 – Konsolidierte Übergabe (22.11.2026)

## Status
Konsolidierter Quellcode-Kandidat für GitHub. **Nicht als auf Android TV funktionsbestätigter Release behandeln.** Die statischen Prüfungen können weder Flutter-/Kotlin-Kompilierung noch Gerätewiedergabe ersetzen.

## Enthaltene Arbeitsbereiche
- Android-TV-D-Pad, Fokuswiederherstellung, Live-TV-Ansichten, EPG-Navigation und Player-Steuerung
- Persistente Media3-PlatformView, HLS/TS-Erkennung, Decoder-Fallback und Pufferstrategie
- Senderwechsel-Serialisierung, generationsgebundene native Events und Startzustand-Snapshot
- Start-/Idle-/Buffer-Watchdogs, Retry-Koordination, Hintergrund- und Lifecycle-Behandlung
- Wiedergabestopp bei Profilberechtigungsentzug, Stopp bei ungültigem Ersatzstream
- Statische Regressionstests für diese Teilbereiche

## In der Abschlusskonsolidierung zusätzlich korrigiert
- Ungültige HTTP(S)-Ersatzadressen (einschließlich leerem Host) stoppen den vorherigen nativen Stream, bevor ein Fehler gemeldet wird.
- Der Regressionstest für doppelte onPause/onStop-Stopps prüft den tatsächlich verwendeten gemeinsamen Lifecycle-Helper.
- Zwei zuvor auseinanderlaufende Regressionstests aus einem parallelen Arbeitsverzeichnis integriert.

## Teststatus
- Alle `tool/check_phase27_5*.py` im konsolidierten Projektstand erfolgreich (Anzahl siehe Übergabeausgabe).
- ZIP-Integrität nach Erstellung separat geprüft.
- **Nicht ausgeführt:** `flutter analyze`, `flutter test`, Android/Kotlin-Build, reale HLS/TS-Streams und Nokia 8000/8010-/TCL-Gerätetests (SDK/Geräte in dieser Umgebung nicht verfügbar).

## Vor produktiver Veröffentlichung erforderlich
1. GitHub-Stand gegen dieses Archiv abgleichen und keine zwischenzeitlichen Änderungen überschreiben.
2. CI: Flutter-Analyse, Tests und Android-Debug-APK erfolgreich bauen.
3. Nokia Streaming Box 8000/8010 und TCL: Senderwechsel, HLS/TS, Bild/Ton-Synchronität, längere Wiedergabe, Decoder-/Frame-Drop-Diagnose testen.
4. Kindersicherung während Streamstart, Profilwechsel und Berechtigungsentzug testen; Hintergrund/Vordergrund, Zurück/Schließen und erneutes Öffnen prüfen.
5. Bei Hardwareproblemen Logcat ohne Zugangsdaten auswerten und Puffer-/Decoderparameter gerätespezifisch nachjustieren.

## GitHub-Commit-Vorschlag
`feat(tv): consolidate phase 27.5 Media3 playback and D-pad stability fixes`

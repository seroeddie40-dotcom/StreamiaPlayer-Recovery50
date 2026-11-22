# Phase 27.5 – Decoderdiagnose (22.11.2026)

Ausgangspunkt: konsolidierte persistente Media3-View (322 Dateien, 199 statische Prüfungen).

## Änderung
`android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt`: Media3 AnalyticsListener beobachtet Decoderinitialisierung, verworfene Videoframes und Audio-Underruns. Ein aggregierter Logcat-Eintrag höchstens alle 60 Sekunden und nur bei Auffälligkeiten. Decodername bei Initialisierung. Keine URLs, Nutzerdaten oder Zugangsdaten. Keine zusätzlichen Timer, Player oder Decoder. Zähler werden beim Senderwechsel und Stop zurückgesetzt.

## Prüfung
21 statische Prüfscripte, darunter `tool/check_phase27_5_decoder_health.py`. Kein Flutter/Gradle-Build oder Android-Gerätetest möglich; Signaturen und tatsächliche Diagnosen müssen mit Media3 1.5.1 im Android-Build bestätigt werden.

## Nächster Schritt
Auf Nokia Streaming Box 8000/8010 und TCL Logcat mit Tag `StreamiaMedia3Health` auswerten, Decoderwahl und Dropped-Frame-/Audio-Underrun-Muster vergleichen. Keine automatischen Performance-Versprechen.

# Phase 27.5 – Native Media3 Lifecycle Guard (21.11.2026)

## Änderung
- `android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt`: Lifecycle-Flag `hostPaused` wird bei Pause/Stop gesetzt und bei Resume zurückgesetzt.
- Ein verzögert eintreffender Flutter-`open`-Methodenaufruf wird während pausierter Activity mit `APP_BACKGROUND` abgelehnt.
- Bereits vorhandenes Stoppen/Leeren des nativen Players, URL-Validierung, Decoder-Release und Listener-Cleanup bleiben bestehen.
- Kein zusätzlicher Player, Decoder oder Timer.

## Testgrenzen
- Quellcode-Vertragsprüfungen, kein Android- oder Flutter-Build.
- Auf Nokia Streaming Box 8000/8010 und TCL reale Home/Resume- und Senderwechsel-Tests erforderlich.
- Statische Prüfungen beweisen keine Ruckelfreiheit.

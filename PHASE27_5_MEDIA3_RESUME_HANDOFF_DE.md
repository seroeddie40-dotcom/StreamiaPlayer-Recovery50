# Phase 27.5 – Media3-Rueckkehr aus dem Hintergrund (21.11.2026)

## Ausgangslage
Androids native TV-PlatformView stoppt und leert den Media3-Player in onActivityPaused/onActivityStopped. Bei Rueckkehr blieb die Flutter-URL unveraendert; damit wurde der Stream nicht automatisch neu geoeffnet.

## Implementiert
- lib/screens/player_screen.dart: Beim tatsaechlichen Rueckweg aus dem Hintergrund wird nur bei Android-TV-Live-TV mit bereits geoeffneter URL, gueltiger Familienberechtigung und ohne Fehler-/Widerrufsstatus die bestehende _loadStream(reconnect: true)-Logik gestartet.
- Vorhandene Generationskontrollen verhindern, dass alte asynchrone Oeffnungen einen neueren Sender ueberholen.
- Die Native-Implementierung und mobile Wiedergabe bleiben unveraendert.

## Tests und Grenzen
- Statische Vertragspruefungen: siehe tool/check_phase27_5_media3_resume.py und weitere Phase-27.5-Skripte.
- Kein Flutter-SDK / Android-TV-Test im Arbeitscontainer; Kompilierung, Hardware-Decoder, Bild/Ton und Rueckkehr aus Home muessen auf Nokia/TCL geprueft werden.
- Bei manuell pausierter Wiedergabe oder Hintergrundwechseln mit systemseitigen Besonderheiten sind weitere Laufzeittests erforderlich.

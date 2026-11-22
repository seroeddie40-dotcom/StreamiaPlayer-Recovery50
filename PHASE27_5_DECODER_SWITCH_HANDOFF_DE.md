# Streamia Player – Phase 27.5: Nativer Decoderwechsel (21.11.2026)

## Änderungen
- `android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt`: Beim Live-TV-Senderwechsel wird die vorherige Media3-Wiedergabe explizit gestoppt und ihre MediaItems entfernt, bevor die nächste Quelle vorbereitet wird. Dadurch können die Ressourcen der alten Quelle früher freigegeben werden.
- Während des synchronen Abbaus und Neuaufbaus werden transiente Player-Status- und Fehlermeldungen unterdrückt. Der Schutz wird in `finally` wieder aufgehoben.
- Auch `stop()` unterdrückt seine eigenen transienten Zustandsmeldungen. Die bestehende Streamgeneration-Absicherung in `TvMedia3PlatformView.kt` bleibt bestehen.
- Keine zusätzlichen ExoPlayer-Instanzen, Decoder, Timer oder Netzwerkanfragen.

## Tests
- Alle Phase-27.5-Quellcode-Prüfscripte ausgeführt (Ergebnis siehe Chat).
- Flutter/Kotlin-Kompilierung und Tests auf Nokia Streaming Box 8000/8010 und TCL nicht durchgeführt: SDK/Geräte hier nicht verfügbar.
- Die Änderungen sind eine gezielte Ressourcen- und Ereignisoptimierung, kein Nachweis einer behobenen TV-Ruckelursache.

## GitHub
`Phase 27.5: Media3 decoder handoff beim Senderwechsel absichern`

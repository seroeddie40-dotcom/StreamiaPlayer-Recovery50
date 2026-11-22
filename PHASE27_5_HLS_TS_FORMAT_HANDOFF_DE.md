# Phase 27.5 – HLS/TS-Quellenauswahl (Zwischenstand)

Basis: Streamia_Phase27_5_Decoderfehler_Retry_Policy_Checkpoint_20261122.zip.

## Änderungen
- Native TvMedia3Playback.kt: explizite HLS-URL-Hinweise (.m3u8/.m3u oder Query-Parameter format/type/extension/ext/output=hls/m3u8) setzen Media3-HLS-MIME.
- Ohne eindeutigen HLS-Hinweis bleibt die Media3-Standarderkennung aktiv, insbesondere für TS/Progressive-Streams.
- Kein zusätzlicher Player, Timer, Decoder oder URL-Logging.
- Alte statische Verträge für den neuen MediaItem-Aufruf aktualisiert; neuer statischer Test mit 9 Prüfungen.

## Prüfung
23 statische Phase-27.5-Prüfscripte bestanden. Kein Flutter-SDK, kein Android-Build, kein Nokia-/TCL-Gerätetest.

## Offen
- HLS-Endpunkte ohne Erweiterung/Format-Hinweis können weiterhin nicht zuverlässig erkannt werden; keine aggressive Fehlklassifikation eingeführt.
- Native Zustands-/Startbestätigung nach open und Verhalten bei schnellen Senderwechseln prüfen.
- Gesamten Phase-27.5-Block erst nach vollständiger Abstimmung auf GitHub übertragen.

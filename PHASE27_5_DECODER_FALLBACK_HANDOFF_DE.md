# Phase 27.5 – Android-TV Decoder-Kompatibilität

## Änderungen
- `TvMedia3Playback.kt`: Media3 `DefaultRenderersFactory` mit `setEnableDecoderFallback(true)`. Bei einem Initialisierungsfehler des bevorzugten Decoders kann Media3 einen weiteren kompatiblen Decoder versuchen. Kein paralleler Decoder und kein erzwungenes Software-Decoding.
- `TextureView` bleibt für die Einbettung in Flutter erhalten und wird ausdrücklich opak gesetzt. Keine ungetestete Umstellung auf `SurfaceView`.
- Der bestehende statische Decoderwechsel-Test wurde auf den expliziten Renderer-Factory-Konstruktor angepasst; neuer Kompatibilitätstest hinzugefügt.

## Grenzen
- Statische Tests sind keine Kotlin-/Flutter-Kompilierung und keine Messung von Frames, Decoder-Auslastung oder Tonrucklern.
- `setEnableDecoderFallback` greift bei Decoder-Initialisierungsfehlern, nicht bei jedem Laufzeitruckeln. Hardwaretests auf Nokia 8000/8010 und TCL sind weiterhin nötig.

## Commit
`Phase 27.5: Media3 Decoder-Fallback und opake TV-TextureView`

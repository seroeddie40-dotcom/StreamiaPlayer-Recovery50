# Phase 27.5 – TV Media3 Pufferstrategie

## Änderungen
- `android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt`: Ein expliziter `DefaultLoadControl` wird an den einzigen vorhandenen ExoPlayer übergeben. Live-Puffer: 10 s Minimum, 25 s Maximum, Start ab 1 s, nach Unterbrechung ab 2 s.
- Der Decoder-Fallback, die opake TextureView, das Stoppen alter Quellen, der Streamgeneration-Schutz und die Berechtigungslogik bleiben erhalten.
- Die bisherige statische Decoder-Fallback-Prüfung wurde an den erweiterten Builder-Aufruf angepasst, ohne die Ein-Player-Anforderung abzuschwächen.

## Grenzen und Risiken
- Die Werte sind ein vorsichtiger Ausgangspunkt und **nicht** auf Nokia 8000/8010 oder TCL gemessen. Mehr Puffer kann Latenz erhöhen; bei sehr instabilen Streams kann weiterhin Ruckeln auftreten.
- Statische Tests prüfen Quelltextverträge, nicht tatsächliche Pufferzeiten, Build oder Android-Hardware.
- Vor Freigabe: `flutter analyze`, Android-Build und Vergleichsmessungen für Live-Zapping, längere Wiedergabe, RAM und A/V-Synchronität auf Zielgeräten.

## Commit
`Phase 27.5: TV Media3 Live-Puffer begrenzen und Rebuffer stabilisieren`

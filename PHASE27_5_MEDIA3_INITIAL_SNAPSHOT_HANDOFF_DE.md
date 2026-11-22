# Phase 27.5 – Media3 Initialzustand nach Open

Zwischenschritt (kein GitHub-Release). Beim nativen `open()` können IDLE-/BUFFERING-Ereignisse synchron eintreten, bevor Flutter die neue Streamgeneration kennt. Ein read-only `snapshot`-MethodChannel-Aufruf nach bestätigtem `open` liefert `playbackState`, `isPlaying` und `streamGeneration`. Flutter verwirft veraltete Snapshots und übergibt nur den aktuellen Zustand an die vorhandene State-Verarbeitung. Keine zusätzlichen Timer, Decoder oder ExoPlayer. Ein Fehler beim Snapshot ist nicht fatal; die vorhandenen Callbacks und Watchdogs bleiben aktiv.

Betroffene vollständige Dateien:
- `android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt`
- `android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt`
- `lib/services/tv_media3_controller.dart`
- `tool/check_phase27_5_media3_initial_snapshot.py`

Commit-Vorschlag: `Phase 27.5: Media3 Initialzustand nach Open generationssicher abgleichen`

Noch offen: echte Flutter-/Kotlin-Kompilierung und Android-TV-Gerätetests, schnelle Senderwechsel und Integrationstest des Gesamtblocks. Nicht vor Blockabschluss auf GitHub hochladen.

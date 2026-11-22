# Phase 27.5 – persistente Android-TV-Media3-View (22.11.2026)

## Änderung
- `lib/screens/player_screen.dart`: Stream-Epoch wird als `reloadToken` übergeben statt als Widget-Key. Dadurch wird die native AndroidView bei Senderwechsel und Reconnect nicht absichtlich entsorgt und neu angelegt.
- `lib/services/tv_media3_controller.dart`: didUpdateWidget öffnet bei URL- oder Tokenwechsel erneut; leere URL stoppt den bestehenden nativen Player. Ungültige URL setzt den Wartestatus zurück.
- `tool/check_phase27_5_media3_resume.py`: Regressionstest auf persistente View angepasst.
- `tool/check_phase27_5_persistent_media3_view.py`: zusätzliche statische Prüfungen.

## Grenzen
- Statische Prüfungen, kein Flutter-/Android-Build oder Gerätetest.
- Native Media3 `open` stoppt weiterhin vor dem neuen Stream und initialisiert den Decoder nach Bedarf neu; nur die unnötige PlatformView/ExoPlayer-Neuerzeugung wird vermieden.
- SurfaceView/TextureView wird nicht gewechselt, um Overlay-/Kompositionsregressionen ohne Hardwaretests zu vermeiden.
- GitHub nicht verändert.

Commit: `Phase 27.5: Android-TV Media3 PlatformView bei Senderwechsel wiederverwenden`

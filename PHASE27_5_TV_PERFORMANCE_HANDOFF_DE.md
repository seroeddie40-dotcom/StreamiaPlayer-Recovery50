# Streamia Player – Phase 27.5 – TV-VOD-Performance
Datum: 21.11.2026 (Projekt-Checkpoint)

## Tatsächlich geändert
- `lib/screens/player_screen.dart`: TV-VOD-Positionsereignisse speichern weiterhin die genaue Position, lösen aber höchstens bei einem neuen Sekundenwert einen Rebuild aus und nur solange Bedienelemente, Verlauf oder Navigation sichtbar sind.
- Smartphone-Positionsaktualisierungen unverändert.
- TV-Live-TV-Pfad unverändert (kein Seekbar-Rebuild).
- Kein zusätzlicher Player/Decoder.
- `tool/check_phase27_5_tv_vod_position_load.py`: acht statische Vertragsprüfungen.

## Prüfungen
- check_phase27_5_back_navigation.py: PASS
- check_phase27_5_cross_navigation.py: PASS
- check_phase27_5_epg_focus.py: PASS
- check_phase27_5_favorite_authorization.py: PASS
- check_phase27_5_ok_controls.py: PASS
- check_phase27_5_tv_columns.py: PASS
- check_phase27_5_tv_favorite_long_ok.py: PASS
- check_phase27_5_tv_focus_restore.py: PASS
- check_phase27_5_tv_vod_position_load.py: PASS

Diese Quellcodeprüfungen sind keine Widgettests, Laufzeitmessungen oder Flutter-Compilation. Flutter SDK ist hier nicht verfügbar. Ein Android-TV-Test auf Nokia/TCL ist erforderlich. GitHub unverändert.

## Offen
- Profiling von Frames, Decoder und CPU auf realen TV-Boxen
- OK/Zurück/Fokus-Widgettests auf realer Fernbedienung
- Flutter analyze, test, Build

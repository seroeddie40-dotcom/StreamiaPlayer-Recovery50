# Phase 27.5 – Media3 IDLE-Watchdog (22.11.2026)

- Flutter: `lib/screens/player_screen.dart` erkennt dauerhaftes Media3 `STATE_IDLE=1` nach dem ersten nativen Statusereignis.
- Zeitlimit 25 Sekunden; wiederholte IDLE-Ereignisse setzen die Uhr nicht zurück.
- READY/BUFFERING/ENDED beenden die IDLE-Uhr. Bestehender Startup-Watchdog (30 s), Puffer-Timeout (60 s) und begrenzte Reconnect-Logik bleiben bestehen.
- Keine neuen Timer, Player oder Decoder.
- Prüfen: statische Tests; kein Flutter/Kotlin-Build oder Hardwaretest.
- GitHub-Commit: `Phase 27.5: Media3 IDLE-Watchdog gegen haengende TV-Streams`

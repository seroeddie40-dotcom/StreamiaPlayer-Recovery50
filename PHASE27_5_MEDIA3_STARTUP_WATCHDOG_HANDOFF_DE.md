# Phase 27.5 – Media3-Start-Watchdog (22.11.2026)

## Änderung
Ein Media3-PlatformView-Start ohne jegliches Statusereignis konnte unbegrenzt hängen, insbesondere bei automatischer Wiederverbindung, weil `_checkPlaybackStall` bei `_reconnecting` früh zurückkehrte. Der bestehende 5-Sekunden-Monitor prüft jetzt einen 30-Sekunden-Start-Watchdog, bevor er `_reconnecting` berücksichtigt. Beim ersten nativen Statusereignis wird der Start-Watchdog deaktiviert und die bisherige 60-Sekunden-Pufferüberwachung übernimmt. Kein zusätzlicher Timer, Decoder oder Player. Die Uhr wird bei Fehler, Berechtigungsentzug, Hintergrundwechsel und neuem Streamstart zurückgesetzt.

## Grenzen
Nur statische Tests. Kein Flutter/Kotlin-Build oder Android-TV-Hardwaretest. Der Watchdog greift nur bei völlig ausbleibenden nativen Statusereignissen; eine dauerhaft IDLE bleibende Wiedergabe nach einem Ereignis bleibt gesondert zu prüfen.

## Commit
`Phase 27.5: Media3 Startup Watchdog fuer haengende TV-Streamstarts`

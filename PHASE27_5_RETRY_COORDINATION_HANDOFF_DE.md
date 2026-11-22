# Phase 27.5 – Retry-Koordination (22.11.2026)

Bei einem späten `playing=true`-Ereignis während der 2–4 Sekunden Retry-Wartezeit wird der geplante Retry abgebrochen. Der Timer-Callback prüft erneut Streamgeneration, Fehlerstatus, Vordergrund und Berechtigung. Damit wird eine bereits wieder angelaufene Wiedergabe nicht durch einen veralteten Retry unterbrochen.

Geändert: `lib/screens/player_screen.dart`. Neuer statischer Test: `tool/check_phase27_5_retry_coordination.py`.

Keine Flutter-/Kotlin-Kompilierung oder Android-TV-Hardwaretests in dieser Umgebung; statische Prüfungen ersetzen diese nicht. GitHub unverändert.

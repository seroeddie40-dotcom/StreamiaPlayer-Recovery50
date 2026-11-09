# Streamia Player – Recovery 67 (09.11.2026)

Basis: Recovery 66.

## Änderungen
- Xtream-API-Aufrufe haben weiterhin 25 Sekunden Timeout, jetzt mit höchstens zwei Versuchen (konfigurierbar für Tests).
- Nur vorübergehende Fehler (HTTP 429/502/503/504, Timeout, Socket-/Client-Verbindungsfehler) werden einmal erneut versucht.
- HTTP 401/403, ungültiges JSON und abgelehnte Konten werden nicht erneut versucht.
- API-Antworttexte und URLs mit Zugangsdaten werden nicht in Fehlermeldungen übernommen.
- Drei neue Tests: HTTP-503-Wiederholung, 403 ohne Wiederholung, Timeout.

## Prüfung / Einschränkungen
- ZIP-Integrität, Dart-Dateiverweise und JSON/YAML werden strukturell geprüft.
- Flutter-SDK nicht installiert; Flutter analyze, Flutter-Tests, APK und echte Android-TV-Tests NICHT ausgeführt.
- Noch offen: zuverlässige Wiederverbindung bei langfristigen Netzunterbrechungen, Streaming-Playback-Fehler, lokalisierte Fehlermeldungen in acht Sprachen.

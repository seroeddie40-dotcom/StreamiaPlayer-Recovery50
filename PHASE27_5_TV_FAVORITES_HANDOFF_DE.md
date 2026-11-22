# Streamia Player – Phase 27.5 – TV-Favoriten / Fokus

## Umsetzung
- `lib/screens/live_tv_screen.dart`: Langes OK auf einem fokussierten TV-Sender ruft die Favoriten-Umschaltung direkt auf. Kurzes OK öffnet weiterhin den Player.
- Der bestehende `pushWithFocusRestore`-Weg für die Rückkehr aus dem Player bleibt erhalten; er wurde in diesem Block nicht verändert.
- Der Favoritenwechsel prüft Profil, Playlist-Quelle und Familienberechtigungen vor und nach asynchronen Operationen. Die vorhandene persistente Favoriten-Outbox und Synchronisierung werden wiederverwendet.
- Keine zusätzliche Favoriten-Schaltfläche/Fokusstation pro TV-Senderzeile, kein zweiter Videodecoder.
- `tool/check_phase27_5_tv_favorite_long_ok.py`: neue statische Vertragsprüfungen.

## Tests
- Favoriten/Player: 11/11 statische Checks bestanden.
- EPG-Fokus: 9/9 statische Checks bestanden.
- TV-Dreispalten: 7/7 statische Checks bestanden.
- TV-Favoriten: 9/9 statische Checks bestanden.
- Flutter analyze/test/build: NICHT ausgeführt (Flutter-SDK in Umgebung nicht vorhanden).
- Echtes Android-TV-Gerät: NICHT getestet.

## Noch offen
- Lang-OK-Dauer und Key-Repeat mit realen D-Pad-Fernbedienungen prüfen.
- Fokuswiederherstellung nach Player-Rückkehr auf Gerät testen, auch bei geänderten/gesperrten Kategorien.
- Favoriten-Synchronisierung gegen Supabase im echten Profil testen.
- Quellcode-Checks sind keine funktionalen Widgettests.

## Commit-Vorschlag
`Phase 27.5: TV long-OK favorites with permission-safe outbox and focus preservation`

Keine GitHub-Dateien wurden ersetzt.

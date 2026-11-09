# Streamia Player – Recovery 72 (09.11.2026)

Basis: Recovery 71. Keine Mediatheken-Integration.

## Änderungen
- Player beobachtet jetzt den Buffering-Status über media_kit.
- Während aktivem Buffering wird die normale 35-Sekunden-Stillstandsprüfung ausgesetzt; nach 60 Sekunden Buffering wird die bestehende Fehler-/Reconnect-Logik ausgelöst.
- Bei Ende des Bufferings wird die Stillstandsuhr neu gestartet.
- Nach Rückkehr aus dem Hintergrund wird die Buffering-Zeit zurückgesetzt.
- Subscription wird beim Schließen des Players freigegeben; bei neuem Stream wird Buffering-Zustand zurückgesetzt.

## Offene Prüfungen
Flutter-SDK ist nicht installiert: kein `flutter analyze`, `flutter test` oder APK-Build. Android-TV-/Smartphone-Hardwaretests stehen aus. Buffering-Timeout auf realen Streams und langsamen Netzen überprüfen.

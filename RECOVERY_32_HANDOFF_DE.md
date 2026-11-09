# Streamia Player – Recovery 32

## Grundlage
Fortsetzung der kanonischen Arbeitskopie `streamia_work_current/streamiaplayer-main` auf Basis Recovery 31.

## Änderungen
- Audio- und Untertitel-Auswahlschaltflächen im Player besitzen separate FocusNodes.
- Nach dem Schließen des Bottom-Sheets wird der Fokus auf die jeweilige auslösende Schaltfläche zurückgeführt.
- Fokus-Ressourcen werden in `dispose()` freigegeben.

## Bewusst unverändert
- Playlist-/Login-Daten und Zugangsdaten
- Watch-Progress und Verlauf
- Audio-/Untertitel-Track-Logik
- Supabase-Schema und Live-Datenbank

## Validierungsgrenzen
- YAML/JSON/relative Imports und ZIP-Integrität können statisch geprüft werden.
- Flutter/Dart SDK nicht verfügbar: kein `flutter analyze`, kein Build, kein APK- oder Gerätetest.
- Kein Live-Zugriff auf Supabase.

## Wiederaufnahme
Mit diesem vollständigen Projektarchiv weiterarbeiten. Kanonischer Projektordner: `streamiaplayer-main/`.

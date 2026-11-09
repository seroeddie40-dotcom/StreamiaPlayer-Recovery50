# Streamia Player – Recovery 30 Übergabe

## Ausgangsbasis
Recovery 30 basiert auf Recovery 29. Kanonischer Arbeitsordner: `streamia_work_current/streamiaplayer-main`.

## Änderungen
1. `lib/screens/series_screen.dart`: Der initiale Episodenfokus wird nur für die erste Episode der ersten Staffel gesetzt. Damit konkurrieren nicht mehr mehrere Staffel-Listen um `autofocus`. Episoden jeder Staffel sind in einer eigenen `FocusTraversalGroup` gruppiert.
2. `lib/screens/player_screen.dart`: Audio- und Untertitelwechsel laufen über eigene asynchrone Hilfsmethoden. Fehler beim Anwenden einer Spur werden per Snackbar angezeigt und nicht mehr still ignoriert.
3. Auswahl-Dialoge schließen vor dem Trackwechsel.

## Grenzen der Prüfung
- Flutter-/Dart-SDK nicht vorhanden: kein `flutter analyze`, `dart format`, Testlauf oder APK-Build.
- Keine Android-TV-Fernbedienung und keine echten Medienstreams verfügbar.
- media_kit-Versionen stehen in `pubspec.yaml`; dynamische Track-Aufrufe konnten nicht live validiert werden.
- Keine Live-Supabase-Änderungen.

## Nächster Schritt
Die tatsächliche Player-API und Trackauswahl mit dem aufgelösten media_kit-Paketstand verifizieren, sobald SDK/Buildumgebung verfügbar ist; anschließend D-pad-Navigation in realen Menüs auf Android TV testen.

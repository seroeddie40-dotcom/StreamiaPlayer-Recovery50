# Recovery 34 – Fernbedienungssteuerung (Fortsetzung)

## Änderungen
- Dashboard-Kopfaktionen (PRO, Designwechsel, Einstellungen) sind mit der Fernbedienung fokussierbar und besitzen Fokus-/Tooltip-Hinweise.
- Download-Aktion auf Filmkarten ist jetzt ein echtes `IconButton` statt eines unbeschrifteten `InkWell`; damit ist sie als separate Aktion per D-pad erreichbar und während eines Downloads deaktiviert.
- Staffel-Download ist jetzt ein `FilledButton.icon` und folgt damit dem nativen Flutter-Fokus- und Aktivierungsverhalten.
- Die bisherigen Fokusgruppen und Traversierungsregeln aus Recovery 33 bleiben erhalten.

## Prüfgrenzen
- Statische Sichtprüfung der geänderten Widget-Strukturen.
- YAML-/JSON-/Import- und ZIP-Prüfungen separat protokolliert.
- Kein Flutter-/Dart-SDK in der Arbeitsumgebung: `flutter analyze`, `flutter test`, APK-Build und Hardwaretests konnten nicht ausgeführt werden.
- D-pad-Navigation muss vor Veröffentlichung zusätzlich auf Android TV / TV-Box und mit Tastatur auf Desktop getestet werden.

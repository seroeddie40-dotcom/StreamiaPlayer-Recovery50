# Streamia Player – Recovery 56

Ausgangsbasis: Recovery 55.

## Änderungen
- Jede lateinische bzw. kyrillische Buchstabentaste mit unterschiedlicher Großschreibung wird als direkt auswählbares Klein- und Großzeichen angezeigt. Ein Shift-Umschalten ist nicht erforderlich.
- Zahlen, Sonderzeichen und URL-Präfixe bleiben direkt verfügbar. Arabische Buchstaben ohne unterschiedliche Groß-/Kleinschreibung erscheinen nur einmal.
- Bestehende Bestätigen-/Abbrechen-Semantik bleibt erhalten.
- Neuer Widget-Regressionstest für direkte Eingabe von `aA`.

## Prüfungen
- ZIP-Integrität, lokale Importziele und Konfigurationsdateien statisch geprüft.
- Flutter-SDK fehlt in dieser Umgebung: Flutter-Tests, Analyse, APK-Build und Hardwaretests wurden nicht ausgeführt.

## Weiteres
- D-Pad-Fokus und automatisches Scrollen auf realen Android-TV-Geräten prüfen.
- Bedienung auf 720p und Eingabe längerer URLs testen.

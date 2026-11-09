# Streamia Player – Recovery 55 (09.11.2026)

Basis: Recovery 54.

## Änderungen
- TV-Tastatur: 10 Bedienelement-Texte in allen acht Sprachen lokalisiert.
- Arabische Oberfläche nutzt RTL-Ausrichtung.
- TV-Tastatur ist in der Höhe begrenzt und intern scrollbar, um kleinere Displays besser zu unterstützen.
- Textfeld ist nur lesbar, damit die Systemtastatur nicht die Fernbedienungs-Tastatur überlagert; Einfügen/Löschen erfolgen über die Bildschirmtasten.
- Erste Zeichentaste erhält Autofokus; übrige Tasten bleiben über das Flutter-Fokussystem erreichbar.
- Widget-Test für Abbrechen und Bestätigen ergänzt (nicht ausgeführt).

## Wichtige Einschränkungen
- Kein Flutter-/Dart-SDK in dieser Arbeitsumgebung: kein flutter analyze, flutter test oder APK-Build möglich.
- Fokusnavigation und Fernbedienung auf realem Android TV noch nicht verifiziert.
- Direkte gleichzeitige Auswahl von Groß-/Kleinbuchstaben pro Taste noch offen; derzeit Umschaltung.
- Android TV Sprach-/Tastatureingabe muss mit echten Geräten getestet werden.

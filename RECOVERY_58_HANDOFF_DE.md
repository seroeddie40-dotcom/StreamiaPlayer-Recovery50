# Recovery 58 – Übergabe (09.11.2026)

Basis: Recovery 57. Änderungen an `lib/widgets/tv_text_keyboard.dart`:
- Android-TV-Tastatur: Escape schließt den Dialog und verwirft den Entwurf; die Android-Zurück-Taste nutzt weiterhin das normale Dialog-Pop-Verhalten (ebenfalls ohne Übernahme).
- Bestätigen und Abbrechen besitzen dauerhafte eigene FocusNodes, sodass sie mit D-Pad/Enter gezielt angesteuert werden können.
- Das schreibgeschützte Vorschau-Eingabefeld nimmt keinen Fokusplatz in der TV-Tastatur-Navigation ein.
- Zwei Widget-Regressionstests ergänzt: Escape verwirft Änderungen; Enter auf fokussierter Bestätigung übernimmt Text.

**Prüfgrenze:** ZIP, JSON/YAML und lokale Importpfade statisch geprüft. Flutter/Dart-SDK nicht vorhanden; Widget-Tests, Analyse, APK und reale Android-TV-Fernbedienung nicht ausgeführt.

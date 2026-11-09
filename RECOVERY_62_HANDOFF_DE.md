# Recovery 62 – Übergabe (09.11.2026)

Basis: Recovery 61. Bei der Prüfung wurde ein kritischer Fehler im Recovery-61-Archiv festgestellt: `lib/widgets/tv_text_keyboard.dart` enthielt irrtümlich Widget-Testcode statt der produktiven `TvTextKeyboard`-Implementierung. Dadurch war Recovery 61 nicht kompilierbar. In Recovery 62 wurde die produktive Implementierung aus Recovery 60 wiederhergestellt und die in Recovery 61 beschriebenen D-Pad-Aktionsübergänge neu integriert.

## Änderungen
- Android-TV-Tastatur wieder als produktive Dart-Klasse verfügbar.
- Pfeiltasten Links/Rechts wechseln zwischen Abbrechen und Übernehmen; Hoch kehrt zur zuletzt fokussierten Taste zurück; an der unteren Grenze führt Runter zu Übernehmen.
- Richtungsereignisse werden im Dialog konsumiert, um doppelte Navigation oder Fokusverlust in den Hintergrund zu vermeiden.
- Zwei zusätzliche Widget-Regressionstests für die Dialoggrenzen.

## Prüfgrenzen
- ZIP-Integrität, JSON-/YAML-Syntax, relative Imports und elementare Quelltextstruktur statisch geprüft.
- Kein Flutter/Dart-SDK installiert: Flutter-Analyse, Testausführung, APK und Android-TV-Hardwaretests **nicht** durchgeführt.
- Recovery 61 bitte nicht mehr als Entwicklungsbasis verwenden. Recovery 62 ist der korrigierte Stand.

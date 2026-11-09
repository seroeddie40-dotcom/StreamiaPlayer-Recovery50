# Streamia Player – Recovery 57

Basis: Recovery 56.

## Änderungen
- Jede Buchstabentaste besitzt einen stabilen eigenen FocusNode, auch bei Neuzeichnungen durch Texteingabe.
- Nach D-Pad-Fokuswechsel wird die ausgewählte Taste bei Bedarf im Scrollbereich sichtbar gehalten.
- Animiertes Scrollen, ohne den gesamten Dialog absichtlich zu verschieben.
- Widget-Test für kleine TV-Auflösung und fokussierte Taste am Ende der Zeichenliste ergänzt.

## Prüfung und Einschränkungen
- Archiv, relative Imports, JSON und YAML strukturell geprüft.
- Flutter-SDK ist nicht installiert; flutter analyze, flutter test und APK-Build nicht ausgeführt.
- Echte D-Pad-Hardwaretests stehen aus.

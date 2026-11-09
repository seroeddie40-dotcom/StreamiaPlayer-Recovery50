# Recovery 66 – Übergabe (09.11.2026)

Basis: Recovery 65.

- Xtream-Eingabevalidierung für HTTP(S)-Serveradresse, Host, Port, Pfad, Benutzername und Passwort vor dem Netzwerkaufruf.
- Ungültige Eingaben erzeugen eine verständliche Meldung und starten keine Verbindung.
- XtreamService-Konstruktion innerhalb try/finally; Client wird auch bei Fehlern geschlossen.
- Generische Fehlermeldung statt unkontrollierter Ausgabe von Ausnahme-Details, die Zugangsdaten enthalten könnten.
- Neuer Unit-Test: test/xtream_input_validator_test.dart.

**Offen:** Flutter SDK hier nicht installiert; kein flutter analyze, flutter test, APK-Build oder Gerätetest durchgeführt.

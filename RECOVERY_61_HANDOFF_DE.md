# Recovery 61 – Übergabe (09.11.2026)

Basis: Recovery 60. Die Android-TV-Tastatur hat jetzt explizite D-Pad-Übergänge zwischen den Aktionsschaltflächen und eine Rücksprungposition zur zuletzt fokussierten Tastaturtaste. Links/Rechts wechselt zwischen Abbrechen und Übernehmen, Hoch führt aus den Aktionen zurück zur Tastatur. An einer unteren Tastaturgrenze führt Runter zu Übernehmen. Richtungsereignisse werden als verarbeitet markiert, damit kein zweiter Traversalmechanismus den Fokus erneut verschiebt.

Zwei Widget-Regressionstests ergänzt. Flutter/Dart-SDK in dieser Umgebung nicht verfügbar: Tests nicht ausgeführt, APK und Hardwaretest offen. ZIP-/Konfigurations-/Import-Prüfungen sind rein statisch.

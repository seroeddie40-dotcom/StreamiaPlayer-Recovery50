# Recovery 65 – Übergabe (09.11.2026)

Basis: Recovery 64.

## Änderungen
- Die Bestätigung der Android-TV-Bildschirmtastatur kann nun einen optionalen `onConfirmed`-Callback auslösen, erst nachdem der Entwurf übernommen und der Dialog geschlossen wurde.
- `VoiceInputField` leitet die bestätigte TV-Eingabe an seinen vorhandenen `onSubmitted`-Callback weiter. Damit führt die Xtream-Eingabe Server → Benutzername → Passwort, auch wenn die TV-Bildschirmtastatur statt der Systemtastatur verwendet wird.
- Die Passwort-Tastatur verschiebt nach Bestätigung den Fokus auf „Verbinden“; bei Abbruch bleibt der Fokusablauf unverändert.
- Zwei neue Widget-Regressionstests prüfen Bestätigen und Abbrechen.

## Prüfgrenzen
Archivstruktur, Importziele und JSON/YAML wurden statisch geprüft. Flutter/Dart-SDK und Android-TV-Testhardware sind hier nicht verfügbar; Tests und APK-Build wurden nicht ausgeführt.

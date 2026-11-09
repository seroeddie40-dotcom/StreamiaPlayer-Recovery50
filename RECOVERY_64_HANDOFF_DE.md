# Streamia Player – Recovery 64 (09.11.2026)

Basis: Recovery 63.

## Änderungen
- TV-Tastatur unterscheidet URL-Eingabe, gewöhnlichen Text und Passwort.
- http:// und https:// erscheinen nur bei URL-Feldern, nicht bei Benutzernamen oder Passwörtern.
- VoiceInputField übergibt URL-Modus automatisch anhand TextInputType.url.
- Passwortfelder erzwingen ausgeschalteten URL-Modus.
- Widget-Tests für Sichtbarkeit und URL-Präfix ergänzt (nicht ausgeführt).

## Prüfstatus
- ZIP-Integrität, relative Imports und JSON/YAML statisch geprüft.
- Flutter-SDK nicht installiert: flutter analyze/test/build und Hardwaretest offen.

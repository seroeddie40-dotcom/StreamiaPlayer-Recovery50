# Streamia Player – Recovery 54

Basis: Recovery 53. Neuer Arbeitsblock: Android-TV-Fernbedienungseingabe.

## Implementiert
- Neue dialogbasierte TV-Tastatur (`lib/widgets/tv_text_keyboard.dart`) mit fokussierbaren Flutter-Buttons für D-Pad/OK.
- Alphabet und Sonderbuchstaben der acht App-Sprachen; Zahlen, URL-Sonderzeichen, Leerzeichen, Löschen, `http://` und `https://`.
- Groß-/Kleinschreibung manuell umschaltbar, standardmäßig Kleinbuchstaben.
- Entwurf wird erst nach OK ins ursprüngliche Eingabefeld übernommen; Abbrechen lässt das Original unverändert.
- Kennworteingabe über denselben Dialog mit verdeckter Anzeige und expliziter Sichtbarkeitsschaltung; keine Sprachdiktierfunktion für Passwörter.
- TV-Tastatur-Schaltfläche in allen VoiceInputFields und im Xtream-Passwortfeld.

## Noch offen
- Sprachübersetzung der Tastatur-Bedienelemente (derzeit englische Standardlabels) und visuelles Feintuning für TV-Auflösungen.
- End-to-End-Test der D-Pad-Fokusführung, IME und Hardware-Fernbedienungen.
- Flutter analyze/test/build und APK-Test: Flutter/Dart SDK in dieser Umgebung nicht vorhanden.
- Eingabefokus auf Fernsehern verschiedener Hersteller und Android-Versionen prüfen.

## Sicherheit und Grenzen
- TV-Tastatur ist eine optionale Alternative zur Android-Systemtastatur, kein globaler Ersatz.
- Eingabe bleibt im Dialog bis OK; Kennwort wird nicht geloggt oder per Sprache erfasst.
- Es wurde kein APK erzeugt und keine erfolgreiche Kompilierung behauptet.

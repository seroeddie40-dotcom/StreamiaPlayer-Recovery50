# Streamia Player – Recovery 45 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 44. Projektname: **Streamia Player**.

## Änderungen in Recovery 45

### Diktierfunktion für Setup-Eingaben
- Neues wiederverwendbares Widget `lib/widgets/voice_input_field.dart` ergänzt.
- Die Diktierfunktion nutzt `speech_to_text` und wählt automatisch eine auf dem Gerät verfügbare Erkennungssprache passend zur aktuell gewählten App-Sprache.
- Unterstützte App-Sprachcodes: Deutsch (`de`), Türkisch (`tr`), Englisch (`en`), Russisch (`ru`), Polnisch (`pl`), Spanisch (`es`), Französisch (`fr`) und Arabisch (`ar`).
- Diktierbutton ist direkt am Eingabefeld erreichbar und besitzt einen sichtbaren Fokuszustand.
- Erkanntes Diktat wird als Text eingesetzt, nicht stillschweigend umformatiert. Nutzer können Serveradresse/Benutzername vor dem Verbinden prüfen und korrigieren.
- Diktat wurde im Setup-Assistenten für M3U-URL, EPG-URL, Xtream-Serveradresse und Xtream-Benutzername ergänzt.
- Das Passwortfeld erhält bewusst keine Mikrofonfunktion. Passwörter sollen nicht versehentlich an einen externen Spracherkennungsdienst übermittelt werden.
- Fehlende Geräteunterstützung bzw. fehlendes Sprachmodell wird in der jeweils gewählten App-Sprache gemeldet.
- Neue Lokalisierungsschlüssel `voice_input` und `speech_language_missing` in allen acht Sprachdateien ergänzt.

### Wichtige technische Grenzen
- Die App kann die auf dem Gerät installierten Spracherkennungsdienste und Sprachmodelle verwenden, aber nicht garantieren, dass jedes Android-Gerät alle acht Sprachen offline oder überhaupt anbietet.
- Android TV-Geräte können ohne Mikrofon oder kompatiblen Speech-Recognizer keine Spracheingabe bereitstellen; die normale D-pad-Eingabe bleibt erforderlich.
- Erkannte URLs werden absichtlich nicht automatisch „repariert“ oder normalisiert, da dies gültige Zeichen verändern könnte. Vor dem Verbinden prüfen.
- Eine eigene Android-TV-Bildschirmtastatur mit direkter Groß-/Kleinschreibung pro Buchstaben ist noch nicht implementiert. Das ist der nächste separate Tastaturblock.
- Android-Smartphone-IME-Sprachen werden vom Betriebssystem bzw. der installierten Tastatur-App verwaltet; Streamia Player kann diese nicht auf jedem Gerät zwangsweise installieren oder umschalten.

## Statische Prüfung
- JSON-Dateien der acht App-Sprachen erfolgreich geparst.
- Neue Lokalisierungsschlüssel in allen acht Sprachdateien vorhanden.
- Relative Dart-Import-/Export-/Part-Verweise werden im Prüfskript kontrolliert.
- ZIP-Integrität separat geprüft.

## Prüfgrenzen
- Kein Flutter-/Dart-SDK in der Arbeitsumgebung; `flutter analyze`, Flutter-Tests und APK-Build nicht ausgeführt.
- Keine realen Android-/Android-TV-Geräte für Mikrofon-, IME- oder D-pad-Tests verfügbar.
- Die tatsächliche Sprachverfügbarkeit hängt vom Speech-Recognizer und installierten Sprachpaketen des Zielgeräts ab.

## Nächste Schritte
1. D-pad-/Fernbedienungs-Matrix für verbleibende Ansichten abschließen.
2. Alle Textfelder inventarisieren und je Feld Eingabeart, Großschreibung, Passwortschutz und Diktierbarkeit festlegen.
3. Eigene Android-TV-Tastatur planen: Groß-/Kleinbuchstaben direkt über die jeweilige Buchstabentaste wechseln, ohne zwingenden Umweg über eine separate Shift-Taste; Layouts für alle acht Sprachen.
4. Smartphone-IME-Verhalten und Android-TV-Tastatur getrennt testen.

# Streamia Player – Recovery 46 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 45. Projektname: **Streamia Player**.

## Änderungen in Recovery 46

### Eingabeverhalten ohne automatische Großschreibung
- Xtream-Serveradresse, Benutzername und Passwort verwenden ausdrücklich `TextCapitalization.none`.
- Passwortfeld deaktiviert Autokorrektur und Textvorschläge, damit Zugangsdaten nicht durch die Eingabemethode verändert werden.
- Das wiederverwendbare `VoiceInputField` unterstützt jetzt FocusNode, `TextInputAction` und `onSubmitted`; bestehende Aufrufer behalten kompatible Standardwerte.

### Server-Schema-Vorschläge
- Über dem Xtream-Serverfeld stehen direkt auswählbare `http://`- und `https://`-Vorschläge.
- Auswahl ersetzt ein bereits vorhandenes HTTP(S)-Schema, statt es doppelt einzufügen, und lässt den übrigen Adresstext bestehen.
- Nach Auswahl wird der Fokus wieder auf das Serverfeld gesetzt.

### Enter-/Weiter-Navigation
- Enter/„Weiter“ im Serverfeld setzt den Fokus auf den Benutzernamen.
- Enter/„Weiter“ im Benutzernamen setzt den Fokus auf das Passwort.
- Enter/„Fertig“ im Passwortfeld setzt den Fokus auf „Verbinden“; der Nutzer bestätigt die Verbindung anschließend bewusst über die Schaltfläche.
- Die Navigation ist in einer Reading-Order-Fokusgruppe angeordnet und für D-pad-/Tastaturbedienung vorgesehen.

## Unveränderte Bereiche
- Keine Änderung an Xtream-Authentifizierung, URL-Aufruf, Zugangsdatenformat, Quellenidentität, Playlist-Import oder Supabase.
- Die Diktierfunktion und ihre sprachabhängige Erkennung aus Recovery 45 bleiben erhalten.

## Prüfgrenzen
- Flutter-/Dart-SDK ist in der Arbeitsumgebung nicht verfügbar; `flutter analyze`, Widget-Tests und APK-Build wurden nicht ausgeführt.
- Kein reales Android-Smartphone bzw. Android-TV-Gerät für IME-/D-pad-Tests verfügbar.
- Die tatsächliche Enter-Aktion der Bildschirmtastatur kann je nach Android-IME variieren; die Fokusweitergabe ist über `onSubmitted` verdrahtet.

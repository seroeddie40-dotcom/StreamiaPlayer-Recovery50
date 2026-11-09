# Streamia Player – Recovery 42

Datum: 09.11.2026  
Arbeitsbasis: Recovery 41

## Schwerpunkt

Fernbedienungs- und D-pad-Bedienung in Setup-Assistent, Kindersperre und Paywall.

## Änderungen

- Setup-Assistent: Tab-Inhalte in eine explizite Reading-Order-Fokusgruppe gesetzt.
- Setup-Assistent: erster QR-Tab-Aktionsbutton erhält den initialen Fokus.
- M3U-/EPG- und Xtream-Eingabefelder zeigen einen deutlichen Fokusrahmen.
- M3U-/EPG-Dateiauswahl erhält einen sichtbaren Fokuszustand.
- Kindersperre: PIN-Ziffernblock und Ordnerliste verwenden eine Reading-Order-Fokusgruppe.
- Kindersperre: erste Ziffer bzw. erster Ordner erhält beim Anzeigen der jeweiligen Ansicht den initialen Fokus.
- Paywall: Tarif- und Laufzeitauswahl sind in einer Reading-Order-Fokusgruppe angeordnet; die erste Laufzeitoption erhält den initialen Fokus.
- Paywall: Fokus-Hervorhebung der Auswahlflächen und Abo-Vorschau-Aktion verstärkt.
- Paywall: Abmelden erfordert nun eine Bestätigung; der Dialog startet auf „Abbrechen“.

## Unverändert

- Keine Änderung an Tarifpreisen oder Tarifauswahl-Daten.
- Kein Zahlungsanbieter und kein echter Zahlungsvorgang ergänzt.
- Keine Änderung an PIN-Speicherung, PIN-Prüfung oder gesperrten Ordnerdaten.
- Keine Änderung an M3U-/EPG-Parsing, Xtream-Verbindung, Authentifizierungsanbieter oder Supabase-RPCs.

## Statische Prüfung

- 50 Dart-Dateien erfasst.
- 8 JSON-Dateien erfolgreich geparst.
- `pubspec.yaml` und `analysis_options.yaml` erfolgreich geparst.
- 150 relative Import-/Export-/Part-Verweise geprüft; keine fehlenden Ziele.
- Klammer-/Delimiterprüfung der drei geänderten Dart-Dateien erfolgreich.
- ZIP-Integrität separat geprüft.

## Nicht durchführbar in dieser Umgebung

- Kein Flutter-/Dart-SDK verfügbar: `flutter analyze`, `dart format`, Widget-Tests und APK-Build konnten nicht ausgeführt werden.
- Keine Android-TV-Hardware bzw. Fernbedienung verfügbar: Fokusreihenfolge und Dialogbedienung müssen auf Zielhardware geprüft werden.
- Keine Live-Supabase-Verbindung; Backend-Laufzeitverhalten wurde nicht getestet.

## Manuelle Testliste für Android TV

1. Setup-Assistent öffnen: QR-Aktion sollte zuerst fokussiert sein; mit rechts/links zwischen den Tabs wechseln.
2. M3U-Tab: URL-/Textfeld, M3U-Dateiauswahl, EPG-Feld und EPG-Dateiauswahl per D-pad erreichen.
3. Xtream-Tab: Server, Benutzername, Passwort und Start-Aktion in sinnvoller Reihenfolge erreichen.
4. Kindersperre öffnen: erste Ziffer sollte fokussiert sein; Ziffern eingeben, löschen und Ordneraktion testen.
5. Paywall öffnen: Laufzeit und Gerätepakete mit D-pad auswählen; Fokus muss sichtbar bleiben.
6. Paywall-Abmelden öffnen: „Abbrechen“ muss zuerst fokussiert sein; mit Zurück schließen und anschließend Abmelden testen.
7. Prüfen, ob Fokus bei langen Inhalten sichtbar bleibt und nicht hinter dem Bildschirmrand verschwindet.

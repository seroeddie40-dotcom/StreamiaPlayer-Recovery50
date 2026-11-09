# Streamia Player – Recovery 47 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 46. Projektname und App-Name bleiben **Streamia Player**.

## Playlist-Profilverwaltung – erste Ausbaustufe

- Neues Modell `PlaylistProfile` ergänzt. Es hält den `sourceKey`, frei wählbaren Anzeigenamen, Quellentyp (M3U/Xtream), Ordnername, Sichtbarkeit, Aktiv-Markierung, Sortierreihenfolge und Erstellungszeit.
- `PlaylistProfileStore` speichert ausschließlich diese Darstellungs-/Organisationsmetadaten lokal in SharedPreferences.
- Server-URLs, M3U-Inhalte, Xtream-Benutzernamen und Passwörter werden ausdrücklich nicht in diesem Profilregister gespeichert.
- Im M3U- und Xtream-Setup gibt es jetzt ein Feld für den persönlichen Playlist-Namen.
- Nach erfolgreichem Laden/Verbinden wird ein Profil angelegt bzw. aktualisiert und als zuletzt aktive Quelle markiert.
- Beim erneuten Hinzufügen desselben `sourceKey` bleiben vorhandener Ordner, Sichtbarkeit und Sortierposition erhalten; der Anzeigename kann aktualisiert werden.
- Neue Playlist-Verwaltungsseite über Einstellungen erreichbar.
- Playlists lassen sich benennen, einem frei eingegebenen Ordner zuordnen, sichtbar/ausgeblendet markieren und in der Reihenfolge verschieben.
- „Playlist hinzufügen“ öffnet den Setup-Assistenten als Unterseite und kehrt nach erfolgreichem Import zur Verwaltung zurück.
- UI-Texte für diesen Funktionsblock sind in allen acht App-Sprachen vorhanden: Deutsch, Türkisch, Englisch, Russisch, Polnisch, Spanisch, Französisch und Arabisch.
- Testdatei `test/playlist_profile_test.dart` ergänzt: JSON-Roundtrip und Aktiv-Markierung beim Upsert.

## Bewusste Abgrenzung / nächster Implementierungsschritt

Dies ist die erste Profil- und Organisationsschicht, noch nicht die vollständige Multi-Playlist-Laufzeitverwaltung:
- Aktuell lädt `ContentProvider` weiterhin genau eine Inhaltsbibliothek gleichzeitig.
- Sichtbarkeit, Ordner und Reihenfolge werden gespeichert und in der Verwaltungsoberfläche dargestellt; sie filtern noch nicht die Hauptnavigation bzw. die Inhaltsdaten, solange die Quellen-Auswahl-/Multi-Source-Schicht nicht integriert ist.
- Ein Wechsel zu einem gespeicherten Profil kann noch nicht automatisch die zugehörige Playlist neu laden. Das benötigt eine sichere Quelle-Konfiguration und eine klare Entscheidung zur geschützten Speicherung von Xtream-Zugangsdaten. Keine Passwörter in SharedPreferences/Klartext ablegen.
- Versteckte Profile bleiben in der Verwaltungsseite sichtbar, damit sie wieder eingeblendet werden können.
- Das bestehende Verhalten von Favoriten, Wiedergabeverlauf und `sourceKey` wurde nicht umgebaut.

## Statische Prüfung
- Alle acht Sprach-JSON-Dateien erfolgreich geparst.
- Alle neuen `playlist_*`-Lokalisierungsschlüssel in allen acht Sprachdateien vorhanden.
- Import-/Export-/Part-Verweise und YAML-Konfiguration werden statisch geprüft.
- ZIP-Integrität separat geprüft.

## Prüfgrenzen
- Kein Flutter-/Dart-SDK in der Umgebung: `flutter analyze`, `flutter test` und APK-Build nicht ausgeführt.
- Keine reale Android-/Android-TV-Hardware für D-pad-, Layout- und Persistenztests verfügbar.
- Der neue Test ist angelegt, aber nicht ausgeführt.

## Nächste Schritte
1. Sichere Quellenkonfiguration für M3U-/Xtream-Profile planen, ohne Zugangsdaten unverschlüsselt abzulegen.
2. Multi-Source-Laufzeitarchitektur aufbauen: aktive Quelle wechseln, Bibliothek laden und pro Quelle Favoriten/Verlauf sauber isolieren.
3. Sichtbarkeit und Ordnerstruktur in die tatsächliche Playlist-/Quellennavigation integrieren.
4. Danach eigene Android-TV-Tastatur mit acht Sprachlayouts, direkter Groß-/Kleinschreibung pro Buchstabe und D-pad-Bedienung umsetzen.

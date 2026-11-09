# Streamia Player – Recovery 36

## Inhalt

Fortsetzung der D-pad-/Tastatur-Fokusverbesserungen auf den Hauptlisten und Verwaltungsansichten:

- **Weiterschauen:** Ergebnisliste in eine eigene Fokusgruppe gelegt; erster Eintrag erhält initialen Fokus und fokussierte Einträge bekommen eine sichtbare Hervorhebung.
- **Favoritenbibliothek:** Ergebnisliste als Fokusgruppe; erster Favorit erhält initialen Fokus; Fokusfarbe ergänzt. Die separate Entfernen-Aktion bleibt als IconButton bedienbar.
- **Geräteverwaltung:** Geräteliste als Fokusgruppe; erster Eintrag erhält initialen Fokus; Fokusfarbe und Tooltip für Statusmenü ergänzt.
- **Suche:** Suchseite als Fokusgruppe; Trefferzeilen erhalten sichtbare Fokusfarbe.
- **Favoriten-Backup:** Aktionen und Inhalte in einer Fokusgruppe zusammengefasst.

## Bewusst unverändert

- Keine Änderungen an Datenmodell, Supabase-RPCs, Authentifizierung, Wiedergabeverhalten oder Lizenzlogik.
- Es werden keine Playlist-Zugangsdaten oder Stream-URLs in Favoriten-Backups ergänzt.

## Validierung

- Statische Sichtprüfung der geänderten Widgets und Klammer-/Einrückungsstruktur.
- JSON-Sprachdateien und `pubspec.yaml` werden im Recovery-Paket erneut geprüft.
- Flutter/Dart SDK ist in der Arbeitsumgebung nicht verfügbar: `flutter analyze`, Dart-Tests, APK-Build und echte Android-TV-/Fernbedienungstests wurden nicht ausgeführt.

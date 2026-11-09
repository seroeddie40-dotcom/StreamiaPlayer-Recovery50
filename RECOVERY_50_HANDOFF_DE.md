# Streamia Player – Recovery 50 Übergabe

Datum: 09.11.2026
Basis: Recovery 49

## Umsetzung
- Neue Dashboard-Komponente `PlaylistSourceNavigation` ergänzt.
- Sichtbare Playlist-Profile werden im Dashboard nach ihrem zugewiesenen Ordner gruppiert.
- Ordner lassen sich per ExpansionTile auf- und zuklappen; Playlist-Auswahl ist per Touch, Tastatur und D-pad erreichbar.
- Aktive Playlist wird gekennzeichnet; Auswahl einer anderen Playlist nutzt den bestehenden `PlaylistSwitchService`.
- Während des Wechsels wird ein Ladeindikator angezeigt; Fehler werden per SnackBar gemeldet.
- Profile mit `isVisible == false` werden in der normalen Dashboard-Quellnavigation nicht angezeigt.
- Ausgeblendete Profile bleiben in der Playlist-Verwaltung erhalten und können dort weiterhin bewusst aktiviert werden.
- Neue Dashboard-Beschriftung in de, tr, en, ru, pl, es, fr und ar ergänzt.

## Nachprüfung und Bedienungsverbesserungen
- Dashboard lädt die Quellnavigation nach dem Verlassen der Einstellungen neu, damit neu angelegte, umbenannte, verschobene oder ausgeblendete Profile sofort berücksichtigt werden.
- Aktive Quelle wird im Dashboard anhand des tatsächlich geladenen `ContentProvider.sourceKey` erkannt; der gespeicherte Profilstatus dient nur als Fallback, solange noch keine Bibliothek geladen ist.
- Dashboard-Kacheln und Quellkarte passen ihre Abstände und Spaltenzahl an schmale Smartphone-Displays an; auf breiten TV-/Desktop-Layouts bleibt das 3-Spalten-Raster erhalten.
- Die Quellnavigation verwendet kompaktere Listeneinträge und eine kleinere Maximalhöhe auf Smartphones.

## Grenzen
- Der ContentProvider hält weiterhin eine aktive Inhaltsbibliothek gleichzeitig. Beim Wechsel wird die gewählte Quelle erneut geladen; parallele, getrennte RAM-Caches je Playlist sind noch nicht implementiert.
- Die Ordner gruppieren Playlist-Quellen. Sie erzeugen keine verschachtelten Sender-/VOD-Unterordner aus M3U/Xtream-Kategorien.
- Lokale M3U-Dateien werden über den in Recovery 49 gespeicherten app-privaten Dateipfad wieder geladen.
- Flutter-Analyse, Tests, APK-Build und Android-/Android-TV-Hardwaretests konnten mangels Flutter-/Dart-SDK und Testgeräten nicht ausgeführt werden.

## Statische Prüfung
- Alle 8 Sprach-JSON-Dateien erfolgreich geparst.
- `pubspec.yaml` und `analysis_options.yaml` erfolgreich geparst.
- 119 relative Import-/Export-/Part-Verweise geprüft; keine fehlenden Ziele.
- ZIP-Integrität separat geprüft.

## Nächster Schritt
- Fokus-/D-pad-Tests und echte Flutter-Analyse nachholen, sobald SDK/Hardware verfügbar sind.
- Anschließend Quellwechsel-Lifecycle, Fehler-Rollback und sourceKey-Isolation für Favoriten/Verlauf prüfen; danach eigene Android-TV-Tastatur fortsetzen.

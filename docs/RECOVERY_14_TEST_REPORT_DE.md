# Recovery 14 – Test- und Änderungsbericht

## Änderungen
- Favoritenbibliothek ist jetzt mit der aktuell geladenen Playlist verknüpft: Ein Antippen öffnet den passenden Sender im Player, einen Film in seiner Detailansicht oder eine Serie in ihrer Detailansicht.
- Die Zuordnung erfolgt ausschließlich über `source_key` und `content_id`. Wenn die ursprüngliche Quelle nicht geladen ist oder der Eintrag fehlt, wird eine verständliche Meldung angezeigt. Es werden keine Stream-URLs aus der Favoritentabelle rekonstruiert oder exportiert.
- Abgebrochene Dateispeicherung beim Favoritenexport wird als normale Benutzeraktion behandelt und nicht als Fehler gemeldet.
- Import-Validierung begrenzt Backups auf 10 MB, 50.000 Einträge sowie definierte Längen für IDs, Quellschlüssel und Titel.

## Prüfstatus
- ZIP-Archiv wird nach Erstellung mit `unzip -t` geprüft.
- JSON-Sprachdateien werden syntaktisch geprüft.
- Relative Dart-Importpfade werden automatisiert auf vorhandene Dateien geprüft.
- Flutter/Dart SDK ist in der aktuellen Arbeitsumgebung nicht verfügbar. `flutter analyze`, Unit-Tests und Android-Build wurden daher nicht ausgeführt.
- Supabase-Migrationen wurden nicht auf einer Live-Datenbank ausgeführt.

## Bekannte Einschränkung
Favoriten bleiben kontogebunden in Supabase. Zum Starten eines Favoriten muss die passende Playlist/Quelle auf dem Gerät geladen sein. Das ist beabsichtigt, weil Favoriten-Backups keine Zugangsdaten und keine Stream-URLs enthalten.

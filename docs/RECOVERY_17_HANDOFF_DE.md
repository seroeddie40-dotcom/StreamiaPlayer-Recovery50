# Recovery 17 – Übergabe

## Änderung
Die Integration der Wiedergabefortschrittsliste wurde verbessert:
- Manuelles Aktualisieren über AppBar-Schaltfläche und Pull-to-refresh.
- Leere Listen sind ebenfalls per Pull-to-refresh aktualisierbar.
- Nach Rückkehr aus dem Player wird die Liste erneut geladen.
- Einträge mit ungültiger Position oder weniger als 20 Sekunden Restlaufzeit werden aus „Weiterschauen“ ausgeblendet; die Historie wird nicht gelöscht.
- Quellenbindung bleibt erhalten: Favoriten und Wiedergabefortschritt werden nur mit der aktuell geladenen Quelle abgeglichen.

## Integrationsbefund
Favoriten speichern keine Stream-URLs oder Zugangsdaten. Die Favoritenbibliothek prüft `source_key` gegen die aktive Quelle und verweigert die Wiedergabe bei abweichender Quelle. „Weiterschauen“ lädt ebenfalls nur Fortschritte der aktiven Quelle und sucht Inhalte anhand stabiler IDs in der geladenen Bibliothek. Bei fehlender/anderer Quelle wird keine alte URL abgespielt.

## Validierung und Grenzen
JSON-Sprachdateien, YAML, relative Dart-Importziele, SQL-Invarianten und ZIP-Integrität werden statisch geprüft. Flutter/Dart SDK und psql sind hier nicht verfügbar; Flutter analyze/tests/APK-Build und SQL-Live-Ausführung wurden nicht durchgeführt. Die Supabase-Migration `202611080004_watch_progress_sync.sql` muss weiterhin manuell angewendet werden.

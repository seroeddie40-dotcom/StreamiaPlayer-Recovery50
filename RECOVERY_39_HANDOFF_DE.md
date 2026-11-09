# Streamia Player – Recovery 39

## Inhalt dieses Wiederherstellungspunkts

- Einstellungen: Fokus-Traversierung der Liste vereinheitlicht; Theme-Umschaltung, Sprachauswahl, Disclaimer, Favoriten, Backup, Kindersperre, Admin-Einstieg und Abmelden besitzen sichtbare Fokuszustände.
- Einstellungen: verschachtelte `InkWell`-/`ListTile`-Konstruktionen bei Theme, Sprache, Kindersperre und Abmelden durch direkt bedienbare `ListTile`-Aktionen ersetzt.
- Abmelden: Sicherheitsdialog ergänzt; „Abbrechen“ erhält den Anfangsfokus.
- Admin-Geräteverwaltung: Lesereihenfolge der Geräteliste explizit festgelegt; die Statusauswahl ist als fokussierbare Popup-Menüaktion ausgeführt.
- Admin-Geräteverwaltung: Sperren/Freigeben erfordert jetzt eine Bestätigung; „Abbrechen“ erhält den Anfangsfokus. Die serverseitigen Admin-RPCs und deren Parameter bleiben unverändert.
- Admin-Geräteverwaltung: Aktualisieren-Schaltfläche erhält einen eindeutigen Tooltip und sichtbaren Fokuszustand.
- Die Navigation über Flutter-Routen bleibt unverändert. Flutter verwaltet pro Route einen eigenen Fokusbereich; die tatsächliche Wiederherstellung des vorherigen Fokus nach `Navigator.pop` muss auf Android-TV-Hardware geprüft werden.

## Bewusst unverändert

- Keine Änderungen an Authentifizierungs-, Zahlungs-, Entitlement-, Playlist-, Player-, Favoriten- oder Datenbanklogik.
- Keine Änderungen an Supabase-RPC-Namen, Parametern oder SQL-Migrationen.
- Die vorhandene serverseitige Admin-Prüfung (`is_streamia_admin`) und das admin-geschützte Laden der Geräte bleiben bestehen.

## Prüfstatus

- Änderungen an den Einstellungen und der Admin-Geräteverwaltung statisch geprüft.
- 51 Dart-Dateien und 8 JSON-Dateien erfasst; alle 8 JSON-Dateien erfolgreich geparst.
- `pubspec.yaml` und `analysis_options.yaml` erfolgreich mit YAML-Parser eingelesen.
- 85 relative Import-/Export-/Part-Verweise geprüft; keine fehlenden relativen Ziele gefunden.
- ZIP-Integrität erfolgreich geprüft; Archiv enthält 139 Dateien.
- Flutter/Dart SDK ist in der Arbeitsumgebung nicht verfügbar. Daher kein `flutter analyze`, kein APK-Build und keine Dart-Tests.
- Keine Tests auf Android-Touch-Geräten oder Android-TV-Fernbedienungen.
- Insbesondere Fokuswiederherstellung nach dem Öffnen/Schließen von Unterseiten und Popup-Menübedienung bleiben auf echter Hardware zu verifizieren.

## Wiederherstellung

Dieses Archiv enthält den vollständigen Projektordner `streamiaplayer-main/`. Den gesamten Ordner extrahieren und diesen Stand als Ausgangsbasis verwenden.

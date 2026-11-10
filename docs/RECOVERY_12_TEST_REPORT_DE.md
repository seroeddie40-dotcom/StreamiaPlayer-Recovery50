# Recovery 12 – Test- und Änderungsbericht

## Änderungen
- Favoriten-Toggle in Live-TV-, Film- und Serienkarten sowie Film-/Seriendetails.
- Accountbasierte Speicherung und Abfrage aus Supabase.
- M3U-Quellfingerprint auf Basis von Quellenidentität und beschreibenden Playlist-Metadaten.
- M3U-IDs deterministisch statt positionsabhängig; volatile URL-Query-Parameter werden bei der ID-Bildung ausgelassen.
- Xtream-Quellfingerprint als Hash aus Server, Benutzer und Kennwort; Klartextdaten werden nicht gespeichert.
- Favoritenmigration mit Update-RLS-Policy und Bereinigung bestehender Dubletten vor Unique-Index.
- Dokumentation zu Voraussetzungen und M3U-Grenzen ergänzt.

## Erfolgreiche statische Prüfungen
- 8 Sprachdateien: JSON-Parsing erfolgreich.
- pubspec.yaml: YAML-Parsing erfolgreich.
- 46 Dart-Dateien: relative Importziele geprüft, keine fehlenden relativen Imports.
- Favoritenaktionen in Live-TV, Film- und Serienansichten vorhanden.
- Migration enthält Update-Policy, Duplikatbereinigung und Unique-Index.

## Nicht ausgeführt
- Flutter Analyze / Flutter Test / Android APK-Build: Flutter/Dart SDK nicht verfügbar.
- SQL-Ausführung / RLS-Live-Test: keine Datenbankverbindung verwendet.
- Android-Gerätetest: nicht ausgeführt.

## Release-Hinweis
Recovery 12 ist eine Entwicklungs- und Wiederherstellungsbasis, kein Store-Release. Die Supabase-Migration `202611080003_account_favorites_sync.sql` muss vor Nutzung der Cloud-Favoriten in Supabase angewendet werden.


## Recovery 13 – Favoritenverwaltung
- Neue Seite „Meine Favoriten“ mit getrennten Sender-, Film- und Serienlisten.
- Favoriten können aus dem Benutzerkonto geladen und einzeln entfernt werden.
- Aktualisieren per Schaltfläche und Pull-to-refresh.
- Hinweis in der Oberfläche, dass Favoriten nur Metadaten speichern; Wiedergabe benötigt die erneut eingebundene passende Playlist.
- Xtream-Quellkennung auf Serveradresse + Benutzername umgestellt; das Passwort wird nicht mehr Bestandteil des Quell-Fingerprints.
- M3U-Quellfingerprint basiert auf deterministischen Inhalts-IDs statt Cover-/Logo-URLs, damit wechselnde Bildadressen nicht die Favoritenzuordnung verändern.

## Recovery 13 – zusätzliche statische Prüfungen
- Neue Favoritenverwaltungsseite auf relative Imports geprüft.
- Einstellungen-Navigation auf vorhandene Favoritenseite geprüft.
- Favoritenlöschung verwendet user_id + content_type + source_key + content_id.
- Keine Playlist-Passwörter oder Stream-URLs in Export-/Favoritenfeldern ergänzt.
- M3U-Fingerprints verwenden nur Host und letzten Stream-Pfadbestandteil; Benutzer-/Passwortsegmente und Query-Tokens werden nicht in den Fingerprint übernommen.

# Recovery 24 – Übergabe

## Änderung
Der Wiedergabeverlauf für Live-TV, Filme und Serien wird jetzt lokal mit `shared_preferences` persistiert.

### Gespeicherte Felder
- `type`, `id`, `title`, `imageUrl`, `sourceKey`, `viewedAt`
- Keine Stream-URL, Playlist-URL, Benutzername oder Passwort.

### Wiederherstellung
Beim Ersetzen/Laden der Inhaltsbibliothek werden Verlaufseinträge der aktiven Quelle anhand der stabilen Inhalts-ID wieder mit den aktuellen Channel-/VOD-/Series-Objekten verknüpft. Die drei Player-Verlauf-Tabs filtern auf die aktive `sourceKey` und zeigen maximal zehn Einträge je Typ.

### Grenzen
- Lokaler Verlauf pro App-Installation/Gerät; keine Cloud-Synchronisierung.
- Inhalte müssen aus derselben Quelle erneut geladen werden, damit die IDs aufgelöst werden können.
- Speicherung ist best-effort; Fehler bei SharedPreferences dürfen die Wiedergabe nicht beeinträchtigen.
- Keine Flutter-/Dart-Toolchain verfügbar: kein `flutter analyze`, keine Tests und kein APK-Build ausgeführt.

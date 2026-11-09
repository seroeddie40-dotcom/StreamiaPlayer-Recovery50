# Streamia Player – Recovery 52 (09.11.2026)

## Änderungen
- PlaylistProfileStore serialisiert Profil-Schreibzugriffe über alle Store-Instanzen. `setActive` und `upsert` lesen und schreiben innerhalb derselben Warteschlange, sodass gleichzeitige Aktivierungen keine verlorenen Aktualisierungen verursachen.
- Cache-Grenze korrigiert: höchstens zwei inaktive Bibliotheken plus eine aktive, also insgesamt drei.
- PlaylistSwitchService gibt `bool` zurück, wenn eine Aktivierung aktuell abgeschlossen wurde. Überholte Aktivierungen zeigen in den beiden Benutzeroberflächen keine irreführende Erfolgsmeldung.
- Playlist-Verwaltung zeigt die aktive Quelle nach Möglichkeit anhand des tatsächlich geladenen ContentProvider statt nur anhand möglicherweise verzögerter Profil-Metadaten.
- Neue Tests für konkurrierende Profil-Aktivierungen und konkurrierendes Upsert/Aktivieren; Cache-Grenztest verschärft.

## Bekannte Grenzen
- Flutter-/Dart-SDK ist nicht installiert; Flutter-Tests, Analyse, APK und echte Geräteprüfungen wurden nicht ausgeführt.
- Der RAM-Cache ist flüchtig. Sehr große Playlists können Speicherprobleme verursachen; reale Android-TV-Messungen stehen aus.
- Änderungen an Profilmetadaten über `saveAll` werden zwar serialisiert, können aber bei veralteten UI-Snapshots weiterhin jüngere Feldänderungen überschreiben; transaktionsartige Feldaktualisierungen sind ein möglicher Folgepunkt.
- Ein bereits gestarteter Profil-Schreibvorgang kann erst nach seinem Abschluss durch eine neuere Aktivierung korrigiert werden. Bei einem Speicherfehler muss die UI die Aktivierung erneut versuchen.
- Keine Streaming-Inhalte werden mitgeliefert.

# Streamia Player – Recovery 40

## Inhalt dieses Wiederherstellungspunkts

- Zentrale Fokus-Rückkehr ergänzt: `lib/core/focus_navigation.dart` stellt nach dem Schließen einer per `Navigator.push` geöffneten Unterseite den Fokus auf das zuvor aktive Element zurück, sofern dessen FocusNode noch existiert, angehängt und fokussierbar ist.
- Die Hilfsfunktion wird für die Navigation vom Dashboard und aus den Einstellungen sowie in Live-TV, Film-/Serienübersichten, Suche, Weiterschauen und Favoriten verwendet.
- Flutter verwaltet weiterhin seine eigenen Route-FocusScopes. Die zusätzliche Wiederherstellung ist ein gezielter Fallback für Fälle, in denen sich der Inhalt einer übergeordneten Seite während einer geöffneten Unterseite neu aufbaut.
- Player-interne `pushReplacement`-Wechsel bleiben bewusst unverändert, weil dort die aktuelle Player-Route ersetzt und nicht als Unterseite zurückgekehrt wird.

## Bewusst unverändert

- Keine Änderungen an Stream-URLs, Playlist-Parsern, Wiedergabe, Verlauf, Favoriten-Daten, Authentifizierung, Supabase-RPCs, Zahlungen oder Entitlements.
- Kein erzwungener Fokus auf ein anderes Element, wenn das zuvor fokussierte Element beim Zurückkehren nicht mehr existiert. In diesem Fall greift Flutter auf die normale Route-/Traversal-Logik zurück.

## Prüfstatus

- Statische Prüfung der Dart-Dateien, Imports und Navigationsaufrufe durchgeführt.
- JSON- und YAML-Konfigurationen werden separat validiert.
- ZIP-Integrität wird nach Erstellung geprüft.
- Flutter/Dart SDK nicht verfügbar: kein `flutter analyze`, kein APK-Build und keine Dart-Tests möglich.
- Keine Android-/Android-TV-Hardware verfügbar. Die D-pad-Prüfung muss auf echter Hardware erfolgen.

## Testcheckliste für Android TV

1. Dashboard: einen Eintrag in der mittleren/rechten Kachelspalte fokussieren, öffnen, mit Zurück schließen; genau diese Kachel muss wieder fokussiert sein.
2. Einstellungen: eine Sprache oder eine Unterseite weiter unten fokussieren, Unterseite öffnen und zurückkehren; der Fokus darf nicht auf die erste Zeile springen.
3. Live-TV / Filme / Serien: ein Element außerhalb der ersten Reihe öffnen, zurückkehren; Fokus auf demselben Element prüfen.
4. Suche und Favoriten: einen Treffer/Favoriten öffnen und zurückkehren; Fokus auf dem ursprünglichen Eintrag prüfen.
5. Während eine Unterseite geöffnet ist, nach Möglichkeit Daten aktualisieren; wenn das ursprüngliche Element entfernt wird, darf kein Absturz auftreten und Flutter muss eine gültige Fokusposition anbieten.
6. OK/Enter und Zurück-Taste sowohl mit Fernbedienung als auch mit Tastatur prüfen.

## Wiederherstellung

Das Archiv enthält den vollständigen Projektordner `streamiaplayer-main/`. Den gesamten Ordner extrahieren und diesen Stand als Ausgangsbasis verwenden.

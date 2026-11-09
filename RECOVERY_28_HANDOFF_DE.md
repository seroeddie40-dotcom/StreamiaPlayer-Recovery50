# Streamia Player – Recovery 28

## Arbeitsgrundlage
Recovery 28 baut auf dem vollständigen Projektstand Recovery 27 auf.

## Änderungen
- Rechte Player-Verlaufleiste zeigt drei vertikal angeordnete, kompakte Akkordeonbereiche: 10 letzte Sender, 10 letzte Filme, 10 letzte Serienepisoden.
- Nur ein Bereich ist gleichzeitig geöffnet. Jeder Bereich zeigt bis zu zehn neueste Einträge und einen separaten Löschknopf.
- Vor dem Löschen wird bestätigt. Gelöscht wird ausschließlich der jeweilige Verlaufstyp der aktuell aktiven Playlist-Quelle; andere Kategorien, Favoriten und Wiedergabefortschritte werden nicht mitgelöscht.
- Live-TV-Verlaufseintrag startet den Sender direkt.
- Film- und Serienepisoden-Auswahl zeigt „Weiterschauen“, „Von vorne starten“ und „Abbrechen“.
- „Von vorne starten“ bei einer Serienepisode beginnt am Anfang der ausgewählten letzten Episode (nicht bei Episode 1 der Serie).

## Daten / Grenzen
- Der lokale Verlauf wird weiterhin durch ContentProvider/SharedPreferences verwaltet.
- Je Kategorie werden in der Player-Seitenleiste maximal zehn Einträge angezeigt.
- Der Verlauf ist weiterhin quellengebunden und wird nicht geräteübergreifend synchronisiert.

## Prüfstatus
- Relative Importziele, Sprach-JSON, pubspec YAML und ZIP-Integrität statisch geprüft.
- Flutter/Dart SDK und Android-Gerätetest waren in der Arbeitsumgebung nicht verfügbar; daher kein Flutter analyze/build oder APK-Test behauptet.

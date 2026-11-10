# Recovery 22 – Live-TV-Ordnernavigation und Zappen

## Änderungen
- Die linke Player-Seitenleiste zeigt bei Live-TV jetzt Sender und Playlist-Kategorien.
- Kategorien werden aus `Channel.category` gebildet; eine Auswahl filtert die Senderliste.
- Die Seitenleiste nutzt denselben halbtransparenten Blur-/Glass-Stil wie die rechte Verlaufleiste.
- Die untere Player-Steuerung bietet bei Live-TV jetzt Aktionen für vorherigen und nächsten Sender.
- Senderwechsel erfolgt innerhalb der aktuell geladenen Kanalliste und verwendet keine fremden Quellen.

## Grenzen
- Die Datenmodelle liefern aktuell eine einzelne Kategorie pro Sender (`Channel.category`). Eine echte mehrstufige Ordnerhierarchie ist in den Quelldaten nicht vorhanden und wurde daher nicht erfunden.
- Sender-Zappen folgt der Reihenfolge der geladenen Kanalliste, nicht einer separaten EPG-/Favoritenreihenfolge.
- Untertitel, Audiospur und Bildformat sind noch nicht als Bedienelemente ergänzt, da die unterstützten Tracks/Formatoptionen für alle Streamtypen erst zuverlässig aus dem Player gelesen werden müssen.
- Flutter-/Android-TV-Laufzeittests konnten in dieser Umgebung nicht ausgeführt werden.

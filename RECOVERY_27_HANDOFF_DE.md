# Recovery 27 – Übergabe

Datum: 08.11.2026

## Änderung
- Die linke Live-TV-Seitenleiste wurde von einer horizontalen Kategorie-Chip-Leiste auf eine zweispaltige Navigation umgestellt.
- Links stehen Playlist-Kategorien, rechts die zugehörigen Sender.
- Die Kategorien bleiben vertikal sichtbar und sind dadurch auf TV-Bildschirmen mit Fernbedienung leichter erreichbar.
- Senderliste und Kategorien liegen in einer FocusTraversalGroup.
- Die vorhandene Filterlogik über `Channel.category` bleibt erhalten.

## Grenzen
- Das Datenmodell `Channel` enthält weiterhin nur ein einzelnes `category`-Feld. Echte verschachtelte Ordner/Unterordner können ohne Erweiterung der Parser und des Modells nicht zuverlässig dargestellt werden.
- Die Navigation wurde statisch geprüft, aber nicht auf Android TV ausgeführt.
- Flutter-/Dart-SDK ist in der Arbeitsumgebung nicht verfügbar; kein Build oder APK-Test behauptet.

## Nächste sinnvolle Schritte
1. Playlist-Formate auf zusätzliche Gruppen-/Pfad-Metadaten untersuchen.
2. Modell und Parser nur dann um `categoryPath`/Ordnerhierarchie erweitern, wenn die Quelldaten dies tatsächlich liefern.
3. Fokuswechsel zwischen Kategorie- und Senderliste sowie Fokus-Rückkehr nach Senderwechsel auf Hardware testen.
4. Untere Steuerung und rechte Verlaufleiste auf Touch- und TV-Layouts prüfen.

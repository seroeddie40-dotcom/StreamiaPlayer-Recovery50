# Streamia Player – Metadatenquellen und Priorität

## Verbindliche Priorität

1. Daten aus Xtream-/Playlist-Antworten und M3U-Metadaten bleiben maßgeblich.
2. Externe Quellen dürfen ausschließlich leere Felder ergänzen.
3. Ein externer Treffer wird nur bei exakt normalisiertem Titel und – wenn vorhanden – passendem Erscheinungsjahr übernommen. Mehrdeutige oder widersprüchliche Treffer werden verworfen.
4. Externe Metadaten dürfen niemals Stream-URLs, Zugangsdaten oder Playlist-Zugangsdaten erhalten.
5. Metadatenfehler, Rate Limits und Offline-Zustände dürfen die Wiedergabe nicht blockieren.

## Anbieter

### Serien: TVmaze

TVmaze ist der erste optionale Serien-Fallback. Der Adapter liefert Serien- und Episodendaten. Die Nutzung unterliegt den TVmaze-Bedingungen und CC BY-SA; erforderliche Attribution und ShareAlike-Pflichten müssen bei einer Veröffentlichung eingehalten und rechtlich geprüft werden. Die Bildnutzung ist gesondert zu prüfen; Playlist-Bilder haben Vorrang.

### Filme: Wikidata

Wikidata wird als kostenloser Textdaten-Fallback verwendet. Die strukturierten Wikidata-Daten stehen unter CC0. Die Implementierung akzeptiert nur exakt passende Titel und prüft zusätzlich, dass die Entität als Film (P31 = Q11424) klassifiziert ist. Bei vorhandener Playlist-Jahresangabe wird ein widersprüchliches Wikidata-Jahr verworfen.

Der Adapter übernimmt derzeit nur Textbeschreibung und Erscheinungsdatum. Er lädt bewusst keine Wikidata-/Wikimedia-Cover automatisch herunter, weil die Lizenz jedes einzelnen Bildes separat geprüft werden muss. Das vermeidet eine pauschale Annahme, dass alle Bilder frei verwendbar seien.

## Cache und Austauschbarkeit

- Positivtreffer werden lokal in SharedPreferences mit 24 Stunden Gültigkeit zwischengespeichert.
- Der Cache ist optional; Fehler beim Cache dürfen die App nicht beeinträchtigen.
- `MetadataProvider` ist die neutrale Schnittstelle. Neue Anbieter werden zentral in `MetadataCatalog` registriert.
- Cache-Schlüssel enthalten Medientyp, normalisierten Titel, Jahr und Sprache.

## Noch vor Release zu erledigen

- Cache auf Größe/TTL und Bereinigungsstrategie prüfen.
- Datenschutz-/Netzwerkhinweis für externe Metadatenabfragen ergänzen.
- TVmaze-Attribution und CC BY-SA-Weitergabeanforderungen juristisch prüfen.
- Wikimedia-Bildrechte nur nach Prüfung pro Datei integrieren.
- API-Verhalten, Rate Limits, Sprachen und Fehlertoleranz auf echten Geräten testen.

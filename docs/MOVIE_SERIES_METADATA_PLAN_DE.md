# Streamia Player – Film- und Serien-Cover & Metadaten

## Produktanforderung
Filme und Serien sollen – soweit Playlist oder eine rechtmäßig nutzbare Metadatenquelle Informationen liefert – mit Covern und Details dargestellt werden. Fehlende Angaben werden nicht erfunden.

## Anzeige
- Poster/Cover, optional Backdrop
- Titel, Jahr, Genres, Beschreibung
- Laufzeit, Altersfreigabe, Bewertung, Regie und Besetzung nur wenn vorhanden
- Serien: Staffeln/Episoden, Titel, Beschreibung, Datum, Laufzeit und optional Episodenbild

## Quellenpriorität
1. Nutzereigene Playlist-/Xtream-Daten.
2. Externe Anbieter über `MetadataProvider`-Schnittstelle.
3. Lokaler Cache.
4. Playlist-Cover oder neutraler Platzhalter.

## Gewählter kostenloser Startanbieter
TVmaze für Serien-Metadaten (kostenlose öffentliche API, CC BY-SA, Attribution und ShareAlike beachten). TVmaze ist kein Filmkatalog. Für Filme bleibt ein austauschbarer Provider vorgesehen; TMDB ist nicht automatisch kostenlos für kommerzielle Nutzung. Details siehe `METADATA_PROVIDER_DECISION_DE.md`.

## Schutz und Zuordnung
- Keine Playlist-Zugangsdaten oder Stream-URLs an Metadatenanbieter senden.
- Nur Titel, optional Jahr und Sprache übertragen.
- Mehrdeutige Treffer nicht automatisch zuordnen.
- Anbieter-ID, Quelle, Lizenz und Attribution behalten.
- Metadatenfehler dürfen Wiedergabe nicht blockieren.

## Favoritenkompatibilität
Favoriten behalten stabile Quellenkennung, Medientyp und Anbieter-ID. Keine temporären Stream-URLs im Backup speichern. Metadatenanbieter können gewechselt werden, ohne Favoriten zu verlieren.

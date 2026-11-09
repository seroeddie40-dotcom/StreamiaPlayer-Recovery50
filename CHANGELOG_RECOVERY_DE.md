## Recovery 80 – CI und installierbare Debug-APK
- GitHub Actions von unsigniertem Release auf Debug-APK mit Flutter-Analyse und Tests umgestellt.
- `.gitignore` für lokale Schlüssel und Build-Dateien ergänzt.
- Deutscher Workflow-/Übergabebericht hinzugefügt.
- Flutter-Ausführung bleibt unbestätigt.

## Recovery 64 – URL-spezifische Android-TV-Tastatur
Nur URL-Felder zeigen Protokoll-Kürzel; Benutzername/Passwort nicht. Tests ergänzt, nicht ausgeführt.

# Aktueller Stand: Recovery 62

# Recovery 62 – Übergabe (09.11.2026)

Basis: Recovery 61. Bei der Prüfung wurde ein kritischer Fehler im Recovery-61-Archiv festgestellt: `lib/widgets/tv_text_keyboard.dart` enthielt irrtümlich Widget-Testcode statt der produktiven `TvTextKeyboard`-Implementierung. Dadurch war Recovery 61 nicht kompilierbar. In Recovery 62 wurde die produktive Implementierung aus Recovery 60 wiederhergestellt und die in Recovery 61 beschriebenen D-Pad-Aktionsübergänge neu integriert.

## Änderungen
- Android-TV-Tastatur wieder als produktive Dart-Klasse verfügbar.
- Pfeiltasten Links/Rechts wechseln zwischen Abbrechen und Übernehmen; Hoch kehrt zur zuletzt fokussierten Taste zurück; an der unteren Grenze führt Runter zu Übernehmen.
- Richtungsereignisse werden im Dialog konsumiert, um doppelte Navigation oder Fokusverlust in den Hintergrund zu vermeiden.
- Zwei zusätzliche Widget-Regressionstests für die Dialoggrenzen.

## Prüfgrenzen
- ZIP-Integrität, JSON-/YAML-Syntax, relative Imports und elementare Quelltextstruktur statisch geprüft.
- Kein Flutter/Dart-SDK installiert: Flutter-Analyse, Testausführung, APK und Android-TV-Hardwaretests **nicht** durchgeführt.
- Recovery 61 bitte nicht mehr als Entwicklungsbasis verwenden. Recovery 62 ist der korrigierte Stand.

---

# Recovery 4 – Änderungen

Datum: 08.11.2026

## Ergänzt gegenüber Recovery 3
- Splash-Screen in den tatsächlichen App-Start eingebunden; zentrale Navigation bleibt danach bei der App.
- Supabase-Initialisierung bleibt vor `runApp` bestehen.
- Bestehende Supabase-Authentifizierung und serverseitige Geräte-/Zugriffs-RPCs wurden beibehalten.
- Mehrsprachiger Disclaimer in Deutsch, Englisch, Türkisch, Russisch, Polnisch, Spanisch, Französisch und Arabisch ergänzt.
- Erststart verlangt eine ausdrückliche Bestätigung; die Bestätigung wird lokal versionsbezogen gespeichert.
- Disclaimer ist zusätzlich in Einstellungen erreichbar.
- Rechtliche Produktgrenze dokumentiert: Player-Software only, keine Inhalte/Playlists/Streams/Abos durch Streamia.

## Prüfstatus
- ZIP-Integrität wird mit `unzip -t` geprüft.
- Sprach- und Projektdateien werden statisch geprüft.
- Flutter/Dart-Analyse und Android-Build wurden in dieser Umgebung nicht ausgeführt.
- Die juristische Eignung der Texte ist nicht anwaltlich geprüft.


## Recovery 5 – 08.11.2026
- Erststart-Reihenfolge korrigiert: Splash → Sprachauswahl → lokalisierter Disclaimer → Login/Registrierung → Geräte-/Zugriffsprüfung.
- Gerätesprache wird als Vorauswahl genutzt, sofern unterstützt; Englisch ist Fallback. Eine aktive Auswahl bleibt erforderlich.
- Disclaimer-Bestätigung wird mit Version, Sprache und UTC-Zeitpunkt lokal gespeichert. Neue Disclaimer-Versionen erzwingen erneute Zustimmung.
- Ablauf in `docs/FIRST_START_FLOW_DE.md` dokumentiert.
- Keine Behauptung eines Flutter-Builds oder Live-Supabase-Tests; diese Prüfungen sind weiterhin offen.

## Favoriten-Sync / Backup
- Neue Supabase-Migration `202611080003_account_favorites_sync.sql` mit stabiler Quellkennung, Kategorieindex und Upsert-Index.
- Neues `FavoritesBackupService` für Cloud-Laden, Export und idempotenten Import.
- Neue Einstellungsseite für Sender-, Film- und Serienfavoriten mit Einzel- und Gesamtexport.
- Backup enthält nur Metadaten, keine Zugangsdaten oder Stream-URLs.
- Siehe `FAVORITES_SYNC_IMPLEMENTATION_DE.md` für Integrationsgrenzen und offene Tests.

## Recovery 6 – Film-/Serien-Metadaten ergänzt
- `VodItem`, `Series` und `Episode` um optionale Metadatenfelder erweitert (Backdrop, Genre, Datum, Altersfreigabe, Laufzeit, Bewertung, Regie/Besetzung, externe ID sowie Episodenbeschreibung/-bild).
- Xtream-Parser liest zusätzliche Metadatenfelder ein, soweit die jeweilige Quelle sie liefert.
- Film-Kacheln zeigen zusätzliche Kurzinfos; neue Film-Detailansicht zeigt Cover-/Backdrop-Bereich, Beschreibung und verfügbare Metadaten.
- Serien-Detailansicht und Episodenlisten zeigen zusätzliche Serien- und Episodeninformationen.
- Neue verbindliche Spezifikation `docs/MOVIE_SERIES_METADATA_PLAN_DE.md` dokumentiert Datenpriorität, externe Metadatenanbieter, Rechte/Datenschutz, Cache, Favoritenkompatibilität und Abnahmekriterien.
- Kein externer Metadatenanbieter festgelegt oder API-Schlüssel eingebaut; M3U-Anreicherung bleibt offen.
- Flutter analyze/build und Geräteprüfung weiterhin nicht ausgeführt.

## Recovery 8 – Metadatenanbieter (08.11.2026)
- Provider-neutrale Schnittstelle `MetadataProvider` und `MetadataCatalog` ergänzt.
- TVmaze als kostenloser, API-Key-freier Startadapter für Serien-Metadaten ergänzt.
- HTTP 429 wird erkannt; optionale Metadatenfehler blockieren die Wiedergabe nicht.
- Anbieter-ID, Quelle, Attribution und Lizenz werden am neutralen Metadatensatz mitgeführt.
- Anbieter-/Lizenzentscheidung dokumentiert: TVmaze für Serien, kein pauschal kostenloser kommerzieller Filmkatalog; TMDB- und IMDb-Einschränkungen festgehalten.
- Film-Metadatenanbieter bleibt austauschbar; keine unzulässige Zusage für Bildrechte.


## Recovery 9 – Playlist-first Metadaten-Anreicherung
- Playlist-/Xtream-Metadaten bleiben immer vorrangig.
- TVmaze wird nur als Serien-Fallback aufgerufen, wenn relevante Daten fehlen.
- Exakte Titel-/Jahresprüfung, damit unsichere Treffer nicht automatisch übernommen werden.
- 24-Stunden-Sitzungscache und Quellen-/Lizenzangaben ergänzt.
- Externe Provider-IDs werden getrennt von IMDb-/TMDB-IDs geführt.
- Serien-Detailansicht zeigt die Attribution und Quellen-URL für TVmaze-Daten.
- Noch offen: persistenter Cache, manuelle Trefferwahl bei Mehrdeutigkeit, Film-Fallback, Lizenzprüfung vor Release und Flutter-/Android-Test.

## Recovery 10 – Serienepisoden-Metadaten
- TVmaze-Episodenabruf für zuvor eindeutig zugeordnete Serien ergänzt.
- Episoden werden ausschließlich über Staffel- und Episodennummer zugeordnet; kein automatisches Fuzzy-Matching einzelner Episoden.
- Playlist-Titel, Beschreibungen, Bilder, Ausstrahlungsdaten und Laufzeiten behalten Vorrang.
- Fehlende Episodenbeschreibungen, Standbilder, Ausstrahlungsdaten und Laufzeiten können aus TVmaze ergänzt werden.
- Episodenmodell speichert Provider-ID, Attribution, Lizenz und Quell-URL.
- Serienansicht zeigt verfügbare Episoden-Standbilder und kennzeichnet externe Episodeninformationen.
- Externe Metadaten bleiben optional; API-Fehler beeinflussen die Wiedergabe nicht.

## Recovery 11 – Film-Metadaten und dauerhafter Cache
- Wikidata als kostenloser Film-Textdaten-Fallback ergänzt (CC0 für strukturierte Daten).
- Film-Entitäten werden zusätzlich auf `P31 = Q11424` geprüft; nur exakte Titel werden akzeptiert.
- Playlist-Daten behalten Vorrang; externe Bilder werden bewusst nicht automatisch übernommen.
- Film-Metadatenabruf in ContentProvider und Film-Detailnavigation integriert.
- 24-Stunden-Cache für Serien-/Film-Metadaten dauerhaft über SharedPreferences ergänzt.
- TVmaze-Episodenlisten ebenfalls lokal zwischengespeichert, damit App-Neustarts nicht erneut alle Episoden abfragen.
- Quellenhinweis, Lizenz und Quell-URL werden in Film- und Serien-Detailansichten angezeigt.
- Provider-Entscheidung und automatisierte Wikidata-Adaptertests ergänzt.

## Recovery 12 – Favoriten direkt in den Medienansichten
- Favoriten-Aktionen in Sender-, Film- und Serienkarten sowie Film-/Seriendetails ergänzt.
- Supabase-Favoriten werden je Benutzerkonto und Kategorie gespeichert.
- M3U-Quelle erhält einen SHA-256-Fingerprint ohne Klartext-URL oder Zugangsdaten.
- M3U-Einträge erhalten deterministische, nicht mehr positionsabhängige IDs; flüchtige URL-Query-Parameter werden bei der ID-Bildung ausgelassen.
- Xtream-Quellidentität wird aus Server/Benutzer/Zugangsdaten gehasht; im Favoritendatensatz landen nur Hash und Hostlabel.
- Favoritenmigration ergänzt Update-RLS-Policy für Upsert und bereinigt Dubletten vor dem eindeutigen Index.
- Details und Grenzen sind in `FAVORITES_SYNC_IMPLEMENTATION_DE.md` dokumentiert.

## Recovery 13 – Favoritenbibliothek
- Eigene Favoritenübersicht für Sender, Filme und Serien ergänzt.
- Einträge können einzeln entfernt und die Listen aktualisiert werden.
- Xtream-Quellfingerprint enthält kein Passwort mehr.
- M3U-Quellfingerprint basiert auf stabilen Medien-IDs statt Cover-/Logo-URLs.
- M3U-Fingerprints vermeiden Benutzer-/Passwortsegmente und Query-Tokens in Streampfaden.

## Recovery 14 – Favoriten öffnen und Backup-Import absichern
- Antippen eines Favoriten öffnet den passenden Eintrag aus der aktuell geladenen Quelle (Live-TV, Film-Detailansicht oder Serien-Detailansicht).
- Quell- und Inhaltskennungen werden vor dem Öffnen abgeglichen; bei nicht geladener/falscher Quelle wird nicht auf eine möglicherweise veraltete Stream-URL zurückgegriffen.
- Abbruch des Export-Speicherdialogs ist kein Fehler mehr.
- Import prüft Dateigröße, Eintragsanzahl und Feldlängen, bevor Supabase-Datensätze geschrieben werden.

## Recovery 15 – Wiedergabefortschritt und „Weiterschauen“ (08.11.2026)
- `WatchProgressService` ergänzt: speichert und lädt VOD-/Serienepisodenpositionen kontobasiert über Supabase.
- Player speichert Positionen alle 15 Sekunden und beim Verlassen; beim erneuten Öffnen wird die letzte Position wiederhergestellt.
- Serienepisoden verwenden die zusammengesetzte Kennung `seriesId::episodeId`, um die zuletzt gesehene Episode über Geräte hinweg zu erkennen.
- Neue Dashboard-Kachel und „Weiterschauen“-Ansicht mit Fortschrittsbalken und Resume-Aktion.
- Lokalisierung für die neue Funktion in Deutsch, Englisch, Türkisch, Russisch, Polnisch, Spanisch, Französisch und Arabisch.
- Neue Migration `202611080004_watch_progress_sync.sql` mit Quellenkennung, Dublettenbereinigung, eindeutigem Index und Benutzer-RLS.
- Wiedergabe bleibt bei fehlender Cloudverbindung oder nicht ausgeführter Migration unabhängig; Offline-Warteschlange ist noch nicht enthalten.


## Recovery 16 – Android-TV-Fernbedienung im Player (08.11.2026)
- Player erhält einen fokussierbaren Eingabebereich für Android-TV-/D-pad-Tastaturereignisse.
- OK/Enter/Select/Leertaste schaltet Wiedergabe/Pause.
- Links/rechts springt bei VOD und Serien um 10 Sekunden; Sprünge werden auf Anfang und bekannte Laufzeit begrenzt.
- Hoch/runter blendet die Player-Steuerung ein.
- Fortschrittsspeicherung verhindert parallele, überlappende Cloud-Schreibvorgänge.
- Die Fernbedienungsbedienung ist eine erste Player-Grundlage; vollständige Fokusnavigation aller App-Bereiche muss separat auf echter Android-TV-Hardware getestet und ergänzt werden.


## Recovery 17 – Weiterschauen-Integration (08.11.2026)
- „Weiterschauen“ kann per Aktualisieren-Schaltfläche oder Pull-to-refresh neu geladen werden.
- Nach Rückkehr aus dem Player wird die Liste automatisch erneut geladen, damit der zuletzt gespeicherte Fortschritt sichtbar wird.
- Leere Listen unterstützen Pull-to-refresh und bleiben damit auch auf Touch-Geräten aktualisierbar.
- Nahezu vollständig abgespielte Inhalte (letzte 20 Sekunden) und ungültige Positionen werden aus „Weiterschauen“ ausgeblendet; die Datensätze bleiben in der Datenbank erhalten.
- Die Favoriten- und Wiedergabefortschrittslisten bleiben quellengebunden. Beim Wechsel der Playlist werden keine veralteten Stream-URLs oder Inhalte anderer Quellen abgespielt.


## Recovery 18 – Offline-Wiedergabefortschritt
- Wiedergabefortschritt wird bei fehlender Verbindung lokal pro angemeldetem Konto zwischengespeichert.
- Neueste Position je Quelle/Inhalt ersetzt ältere Queue-Einträge; Warteschlange ist auf 100 Einträge begrenzt.
- Ausstehende Einträge werden bei späteren Lese-/Speichervorgängen erneut synchronisiert.
- Queue enthält nur Benutzer-ID, Quellen-/Inhaltskennung, Titel, Position, Laufzeit und Zeitstempel; keine Stream-URLs oder Zugangsdaten.
- Geräte-/Netzwerk-Ende-zu-Ende-Test bleibt erforderlich.


## Recovery 19 – Offline-Synchronisierung robuster machen (08.11.2026)
- Ausstehender Wiedergabefortschritt wird während geöffneter Player-Ansicht alle 30 Sekunden erneut übertragen.
- Beim Zurückkehren der App in den Vordergrund wird die Synchronisierung erneut angestoßen.
- Beim Wechsel in inaktive/pausierte App-Zustände wird der aktuelle Fortschritt gespeichert.
- Queue-Operationen sind serialisiert, damit gleichzeitige Flush- und Queue-Schreibvorgänge keine neueren Einträge überschreiben.
- Queue-Einträge werden dem aktuell angemeldeten Konto zugeordnet; ein Kontowechsel führt nicht zum Schreiben alter Queue-Daten in das neue Konto.
- Hintergrund-Synchronisierung nach Beenden der App ist weiterhin nicht garantiert.


## Recovery 20 – Android-TV-Fokusnavigation in Inhalts- und Einstellungsansichten (08.11.2026)
- Live-TV-, Film- und Serienraster sind jeweils in eine eigene FocusTraversalGroup eingebettet.
- Erstes Element in jedem Raster erhält beim Öffnen den initialen Fokus.
- Fokusfarbe hebt aktuell ausgewählte Kacheln auf TV-Geräten sichtbar hervor.
- Episodenlisten in Serien-Detailansichten erhalten einen initialen Fokus auf die erste Episode; Download-Aktionen bleiben separat bedienbar.
- Dashboard-Raster und Einstellungs-Liste unterstützen explizite Fokusgruppen; erste Dashboard-Kachel bzw. erste Einstellungsaktion erhält den initialen Fokus.
- Die Umsetzung nutzt Flutter-Fokus-/Traversal-Mechanismen; reales D-pad-Verhalten, Fokus-Rückkehr nach Unterseiten und Sonderfernbedienungen müssen auf Android-TV-Geräten geprüft werden.

## Recovery 21 – Einheitliche rechte Verlaufleiste (08.11.2026)
- Verlaufmodell in `ContentProvider` auf typisierte Einträge für Live-TV, VOD und Serien erweitert.
- Je Kategorie werden die zehn neuesten Einträge für die Player-Seitenleiste bereitgestellt.
- Rechte Player-Leiste in drei umschaltbare Bereiche (Live, Filme, Serien) aufgeteilt und mit halbtransparentem Blur-/Glass-Look versehen.
- Auswahl eines Verlaufseintrags öffnet den zugehörigen Live-Sender, Film oder eine Episode der Serie.
- Episodenliste links erhält ebenfalls den transparenten Glass-Look und einen Staffeln-/Episoden-Titel.
- Grenzen: Verlauf ist derzeit sitzungs-/speicherlaufzeitbezogen und noch nicht dauerhaft gespeichert. Serienauswahl startet aktuell die erste verfügbare Episode; die Auswahl der zuletzt angesehenen Episode und „Weiterschauen / von vorne“ wird im nächsten Schritt mit `watch_history` verbunden. Allgemeine Live-TV-Ordnernavigation links und untere kontextabhängige Mediensteuerung sind noch nicht vollständig umgesetzt.

## Recovery 22 – Live-TV-Navigation im Player (08.11.2026)
- Linke Glass-Seitenleiste zeigt Live-TV-Kategorien aus `Channel.category` sowie die zugehörigen Sender.
- Kategorie-Chips filtern die Senderliste; „Alle“ zeigt wieder sämtliche geladenen Sender.
- Auswahl eines Senders wechselt direkt im Player zum gewählten Kanal.
- Untere Live-TV-Steuerung ergänzt Aktionen für vorherigen/nächsten Sender (Zappen in Playlist-Reihenfolge).
- Mehrstufige Ordnerstruktur bleibt offen, weil das aktuelle Kanalmodell nur ein Kategorienfeld bereitstellt.

## Recovery 24 – Persistenter lokaler Wiedergabeverlauf (08.11.2026)
- Verlaufseinträge für Live-TV, Filme und Serien werden lokal in SharedPreferences gespeichert.
- Gespeichert werden nur Typ, stabile Inhalts-ID, Titel, Vorschaubild-URL, Quellenkennung und Zeitstempel; keine Playlist-Zugangsdaten und keine Stream-URLs.
- Nach erneutem Laden einer Playlist werden Verlaufseinträge anhand der Quellenkennung und stabilen Inhalts-ID wieder mit den aktuell geladenen Objekten verknüpft.
- Die Player-Verlaufskategorien zeigen ausschließlich Einträge der aktuell aktiven Quelle; pro Kategorie weiterhin maximal zehn Einträge.
- Verlauf bleibt lokal auf dem Gerät. Cloud-/Kontosynchronisierung des Verlaufs ist damit ausdrücklich noch nicht umgesetzt.
- Speicherung ist best-effort und blockiert die Wiedergabe nicht.


## Recovery 25 – Verlauf mit tatsächlicher Fortsetzungsposition verbinden (08.11.2026)
- Auswahl eines Films in der rechten Verlaufleiste fragt bei vorhandenem Wiedergabefortschritt „Weiterschauen“ oder „Von vorne starten“ ab.
- „Von vorne starten“ unterdrückt gezielt das automatische Wiederherstellen der gespeicherten Position; die alte Position wird nicht vorzeitig gelöscht.
- Serienverlauf durchsucht die letzten gespeicherten Episodenfortschritte der aktuellen Quelle und ermittelt anhand des Schlüssels `seriesId::episodeId` die zuletzt gesehene verfügbare Episode.
- Bei Serien kann die letzte Episode fortgesetzt oder die Serie ab der ersten verfügbaren Episode neu begonnen werden.
- Wenn kein gültiger Fortschritt vorhanden ist, startet der ausgewählte Inhalt direkt von vorne, ohne unnötigen Dialog.
- Die Auflösung verwendet ausschließlich Inhalte der aktuell geladenen Playlist-Quelle.
- Flutter-/Geräte- und Supabase-Live-Tests bleiben erforderlich; in dieser Umgebung erfolgte nur eine statische Prüfung.

## Recovery 26 – Kontextabhängige untere Media-Steuerung (08.11.2026)
- Untere Player-Steuerung ergänzt um 10-Sekunden-Sprung zurück/vor für VOD und Serien.
- Audiospurauswahl ergänzt: verfügbare Audio-Tracks werden aus dem Player-Trackstatus angeboten; Auswahl wird an media_kit weitergereicht.
- Untertitelauswahl ergänzt: explizite Option „Aus“ sowie verfügbare Untertitel-Tracks.
- Bilddarstellung kann zwischen „Original“ (contain), „Ausfüllen“ (cover) und „Strecken“ (fill) umgeschaltet werden.
- Nicht verfügbare oder vom Stream nicht gemeldete Audio-/Untertitelspuren führen zu einer verständlichen Meldung statt zu einem Absturz.
- Die Audio-/Untertitelintegration nutzt zur Laufzeit abgesicherte dynamische Zugriffe; echte Medien-Track-Kompatibilität muss mit den tatsächlich verwendeten media_kit-Versionen und unterschiedlichen Streams getestet werden.
- Flutter-Build und reale Android-/Android-TV-Tests bleiben offen.

## Recovery 27 – Zweispaltige Live-TV-Navigation (08.11.2026)
- Linke Player-Seitenleiste in eine zweispaltige Navigation umgebaut: Kategorien links, Sender der ausgewählten Kategorie rechts.
- Die bisherige horizontale Chip-Leiste entfällt; lange Kategorienamen können in der vertikalen Liste umbrechen.
- Senderliste und Kategorien sind in einer FocusTraversalGroup angeordnet, um die D-pad-Navigation zu unterstützen.
- Filterung basiert weiterhin auf dem vorhandenen `Channel.category`-Feld.
- Echte verschachtelte Ordner bleiben offen, bis Playlist-Parser und Kanalmodell nachweislich entsprechende Pfadinformationen bereitstellen.
- Statische Prüfungen und Archivintegrität geprüft; Flutter-Build und Hardwaretest nicht verfügbar.

## Recovery 28 – Rechte Verlaufleiste als drei kompakte Bereiche (09.11.2026)
- Die rechte Verlaufleiste wurde von drei horizontalen Umschalt-Tabs auf drei untereinander angeordnete, einklappbare Bereiche umgestellt: „10 letzte Sender“, „10 letzte Filme“ und „10 letzte Serienepisoden“.
- Es ist jeweils höchstens ein Bereich geöffnet; dadurch bleibt die Seitenleiste übersichtlich und verschachtelt sich nicht unnötig.
- Jeder Bereich zeigt separat seinen Eintragszähler und besitzt eine eigene Löschaktion mit Sicherheitsabfrage. Das Löschen betrifft nur den gewählten Verlaufstyp der aktuell aktiven Playlist-Quelle.
- Die Eintragslisten verwenden weiterhin die jeweils zehn neuesten Einträge; Live-TV-Auswahl schaltet direkt um, Film- und Episodenauswahl öffnen den Wiedergabedialog.
- Korrektur bei Serien: „Von vorne starten“ beginnt jetzt am Anfang der ausgewählten letzten Episode und springt nicht mehr fälschlich an den Anfang der gesamten Serie.
- Serien-Dialog benennt die gespeicherte Position ausdrücklich als Position innerhalb der ausgewählten Episode.
- Statische Quelltext-/Import-/JSON/YAML- und ZIP-Prüfungen durchgeführt. Flutter-Analyse, APK-Build und Gerätetest bleiben mangels SDK/Hardware in dieser Umgebung offen.

## Recovery 29 – Fernbedienungsnavigation und Playlist-Bestandsaufnahme

- Player-Tastensteuerung korrigiert: Bei sichtbaren Player-Steuerelementen werden Links/Rechts nicht mehr pauschal als 10-Sekunden-Sprung abgefangen. Dadurch kann Flutter die Fokusnavigation zwischen fokussierbaren Steuerelementen übernehmen.
- Auf/Ab blendet die Player-Steuerleiste nur ein, wenn sie ausgeblendet ist; bei sichtbarer Leiste bleiben die Richtungstasten für die Navigation verfügbar.
- Der Verlaufsbereich ist zusätzlich als eigene `FocusTraversalGroup` abgegrenzt.
- M3U-/Xtream-Parser geprüft: M3U liefert derzeit nur das einzelne `group-title`-Attribut als flache Kategorie. Xtream-Einträge übernehmen `category_name`; Kategorien werden aktuell nicht als eigene Baumstruktur geladen. Eine echte mehrstufige Ordnernavigation wird deshalb nicht künstlich aus Trennzeichen abgeleitet. Dafür ist eine explizite, quellenspezifische Kategorie-Hierarchie erforderlich.
- `media_kit` / `media_kit_video` Versionsstand und dynamische Audio-/Untertitel-Auswahl geprüft; die Laufzeit-API konnte ohne Flutter-/Dart-SDK und echte Streams nicht verifiziert werden.


## Recovery 30 – Episodenfokus und Track-Fehlerbehandlung (09.11.2026)
- Serien-Detailansichten setzen den initialen D-pad-Fokus nur noch auf die erste Episode der ersten Staffel. Zuvor konnte jede Staffel ihren ersten Eintrag gleichzeitig mit `autofocus` markieren.
- Episoden je Staffel sind zusätzlich in einer eigenen `FocusTraversalGroup` zusammengefasst.
- Audio- und Untertitelauswahl melden jetzt einen tatsächlichen Fehler beim Anwenden einer Spur, statt Fehler beim Trackwechsel still zu verschlucken.
- Die Auswahl-Dialoge schließen vor dem asynchronen Trackwechsel; die Wiedergabeoberfläche bleibt dadurch bedienbar.
- Statische Prüfungen durchgeführt. media_kit-Laufzeitverhalten und D-pad-Verhalten bleiben mangels SDK/Hardware/Streams unbestätigt.


## Recovery 31 – Typisierte Audio-/Untertitelauswahl (09.11.2026)
- Dynamische Zugriffe auf `Player.state.tracks` und `Player.setAudioTrack` / `setSubtitleTrack` entfernt. Die Auswahl verwendet jetzt die typisierten `AudioTrack`- und `SubtitleTrack`-APIs von `media_kit`.
- Die Dialoge bieten explizit „Automatisch“; Untertitel können zusätzlich gezielt ausgeschaltet werden.
- Interne `auto`-/`no`-Platzhalter werden nicht als normale Streamspuren doppelt angezeigt.
- Die aktuell ausgewählte Spur wird im Dialog mit Häkchen und hervorgehobener Beschriftung markiert.
- Spurnamen kombinieren vorhandenen Titel und Sprache; fehlende Metadaten werden robust abgefangen.
- API-Abgleich anhand der offiziellen `media_kit`-Dokumentation. Die Projektangabe `media_kit: ^1.1.10` erlaubt 1.x-Versionen; ohne Lockfile/Flutter-SDK konnte die tatsächlich aufgelöste Version nicht ermittelt und kein Build ausgeführt werden.

## Recovery 32 – Fokus-Rückkehr nach Audio-/Untertitelauswahl
- Audio- und Untertitel-Schaltflächen besitzen nun eigene, benannte FocusNodes.
- Nach dem Schließen der jeweiligen Auswahl (auch per Zurück-Taste) wird der Fokus im nächsten Frame auf die auslösende Schaltfläche zurückgesetzt.
- Die FocusNodes werden beim Verlassen des PlayerScreens freigegeben.
- Keine Änderung an Streamauswahl, Wiedergabefortschritt oder Verlaufsspeicherung.
- Prüfung: statische Struktur-/Import-/Konfigurationschecks; kein Flutter SDK für `flutter analyze` oder APK-Build vorhanden.

## Recovery 33 – zentrale Fernbedienungsnavigation
- Globale `FocusTraversalGroup`-Umgebung mit `ReadingOrderTraversalPolicy` im `MaterialApp` ergänzt. Damit erhalten auch Login, Setup, Suche, Fortsetzen, Favoriten, Rechtliches, Paywall und Admin-Ansichten eine konsistente D-pad-/Tastatur-Traversierung, soweit ihre Bedienelemente Flutter-Fokus unterstützen.
- Player-Steuerungsoverlay zusätzlich als eigene Fokus-Traversierungsgruppe abgegrenzt.
- Keine Änderungen an Wiedergabe-, Verlaufs-, Favoriten- oder Entitlement-Datenlogik.
- Validierung: Quelltext-/Import-/Konfigurationsprüfungen und ZIP-Integrität; kein Flutter-/Dart-SDK in der Arbeitsumgebung, daher kein echter Build oder Gerätetest.

## Recovery 34 – Gesamtsteuerung (Fortsetzung)
- Dashboard-Aktionen PRO, Designwechsel und Einstellungen für D-pad mit Fokuszuständen und Tooltips verbessert.
- Film-Download-Aktion auf Karten in einen fokussierbaren IconButton umgewandelt.
- Staffel-Download-Aktion auf FilledButton.icon umgestellt, damit Flutter-Standard-Fokus und Enter/OK-Aktivierung greifen.
- Prüfgrenzen und offene Hardwaretests in `RECOVERY_34_HANDOFF_DE.md` dokumentiert.

## Recovery 35 – Fokuszustände in weiteren Bereichen (09.11.2026)
- Sprachauswahl-Kacheln erhalten einen gut sichtbaren Fokus-Hintergrund und abgerundete Fokusfläche.
- Ziffernblock und Ordneraktionen der Kindersperre erhalten konsistente Fokus-Hervorhebung für D-pad/Keyboard.
- Tarifzeitraum, Gerätepaket und Paywall-Vorschau-Aktion erhalten sichtbare Fokuszustände; die Vorschau löst weiterhin keine Zahlung aus.
- Favoriten-Schaltfläche ist im nicht angemeldeten Zustand als deaktivierter IconButton mit Erklärung umgesetzt statt als rein dekoratives Icon.
- Keine Änderung an Konten, Berechtigungen, Zahlungslogik oder Datenbank.
- Statische Prüfungen; Flutter-/Dart-Analyse, APK-Build und Hardwaretests mangels SDK/Hardware nicht möglich.

## Recovery 36 – Listensteuerung und Fokusgruppen (09.11.2026)

- Fokusgruppen und sichtbare Fokuszustände in Weiterschauen, Favoritenbibliothek, Geräteverwaltung und Suche ergänzt.
- Favoriten-Backup-Aktionen in einer Fokusgruppe gebündelt.
- Keine Änderungen an Backend, Datenmodell oder Wiedergabe.
- Flutter-Analyse, APK-Build und Hardwaretests bleiben offen.

## Recovery 37 – Player-Steuerung und Dialogfokus (09.11.2026)
- Player-Overlay-Aktionen, Verlaufskopfzeilen, Episoden- und Kategoriezeilen erhalten sichtbare D-pad-Fokuszustände.
- Schließen-, Senderwechsel- und Verlauf-Löschaktionen erhalten Fokusfarben.
- Bestätigungsdialoge fokussieren initial die sichere Option „Abbrechen“.
- Keine Änderungen an Wiedergabe-, Datenbank-, Authentifizierungs- oder Lizenzlogik.
- Flutter-Analyse, APK-Build und Hardwaretests bleiben mangels SDK/Hardware offen.

## Recovery 38 – Login, Rechtliches und Setup (09.11.2026)
- Login-/Registrierungsformular in Fokusgruppe organisiert; E-Mail-Feld erhält den Anfangsfokus und einen sichtbaren Akzentrahmen.
- Fokusfarben für Anmelden und Wechsel zwischen Login/Registrierung ergänzt.
- Rechtliche Erstbestätigung: Checkbox erhält den Anfangsfokus; Bestätigungsschaltfläche mit Fokuszustand versehen.
- Playlist-Setup: Tab-Inhalte in Fokusgruppe organisiert und Start-/Dateiaktionen mit Fokusfarbe versehen.
- Keine Änderungen an Authentifizierungs-, Playlist-, Lizenz- oder Backendlogik.
- Flutter-Analyse, APK-Build und Hardwaretests bleiben offen.


## Recovery 39 – Einstellungen und Admin-Geräteverwaltung (09.11.2026)
- Fokusführung in den Einstellungen vereinheitlicht und sichtbare Fokuszustände für die zentralen Aktionen ergänzt.
- Abmelden durch eine Bestätigungsabfrage mit sicherem Anfangsfokus auf „Abbrechen“ abgesichert.
- Admin-Geräteverwaltung: Statusmenü für D-pad/Tastatur fokussierbar; Sperren/Freigeben wird vor dem unveränderten Admin-RPC bestätigt.
- Aktualisieren-Schaltfläche mit Tooltip und sichtbarem Fokuszustand ergänzt.
- Keine Änderungen an Supabase-RPCs, SQL-Migrationen oder Berechtigungslogik.
- Prüfgrenze: kein Flutter/Dart SDK, daher keine Flutter-Analyse, kein APK-Build und keine realen Android-TV-Tests.


## Recovery 40 – Fokus-Rückkehr bei Unterseiten (09.11.2026)
- Neue zentrale Navigationshilfe `lib/core/focus_navigation.dart`: merkt den Fokus vor `Navigator.push` und stellt ihn nach Rückkehr wieder her, sofern das ursprüngliche Element noch im Widget-Baum vorhanden und fokussierbar ist.
- Dashboard- und Einstellungsnavigation sowie Unterseiten für Live-TV, Filme, Serien, Suche, Weiterschauen und Favoriten auf die neue Hilfsfunktion umgestellt.
- Flutter-Route-FocusScopes bleiben aktiv; keine Änderungen an Backend-, Playlist-, Konto-, Zahlungs- oder Playerlogik.
- Statische Prüfungen und ZIP-Integrität durchgeführt; Flutter-Analyse, APK-Build und reale Fernbedienungstests mangels SDK/Hardware weiterhin offen.

## Recovery 41 – Fokuszustände in Favoriten, Suche und Admin (09.11.2026)
- Favoriten-Entfernen: Dialog fokussiert zunächst „Abbrechen“; Dialogaktionen, Aktualisieren, Entfernen, Kategorieauswahl und Fehler-Wiederholen erhalten sichtbare Fokuszustände.
- Weiterschauen: Aktualisieren und Fehler-Wiederholen sind klar fokussierbar.
- Sprachsuche: Mikrofon- und Sprachwahlaktionen erhalten Fokusfarben; Sprachauswahl startet auf der aktuell gewählten Sprache bzw. dem ersten verfügbaren Eintrag.
- Admin-Geräteverwaltung: Fehlerzustand erhält eine fokussierbare Wiederholen-Aktion; Statusdialog-Aktionen zeigen Fokuszustände.
- Keine Änderungen an Supabase-RPCs, Favoriten-Datenmodell, Authentifizierung, Playlist- oder Wiedergabelogik.
- Flutter-Analyse, APK-Build und reale D-pad-/Android-TV-Tests bleiben mangels SDK/Hardware offen.

## Recovery 42 – Setup, Kindersperre und Paywall (09.11.2026)
- Setup-Assistent: Reading-Order-Fokusgruppe, initialer Fokus der QR-Aktion sowie deutlichere Fokusrahmen für Eingaben und Dateiauswahl.
- Kindersperre: Reading-Order-Fokusführung und initialer Fokus für PIN-Ziffernblock und Ordnerliste.
- Paywall: Fokusnavigation und Hervorhebung für Tarifauswahl verbessert.
- Paywall-Abmeldung durch Bestätigungsdialog mit initialem Fokus auf „Abbrechen“ abgesichert.
- Zahlungs-, Tarif-, PIN-, Playlist-, Authentifizierungs- und Backendlogik unverändert.
- Statische Prüfungen erfolgreich; Flutter-Analyse, APK-Build und reale Android-TV-Tests mangels SDK/Hardware weiterhin offen. Details: `RECOVERY_42_HANDOFF_DE.md`.

## Recovery 43 – Setup-Stabilität und Unicode-Dateiimport (09.11.2026)
- Optionalen WLAN-IP-/QR-LAN-Import gegen Fehler abgesichert; manuelle Playlist-Einrichtung bleibt bei Ausfall nutzbar.
- BuildContext nach asynchroner IP-Ermittlung nur nach Mounted-Prüfung verwendet.
- QR-Link wird nur bei erfolgreich gestarteter lokaler Importserver-Adresse angezeigt.
- M3U-Dateien werden UTF-8-tolerant dekodiert, damit internationale Sendernamen nicht durch Byte-zu-Zeichen-Konvertierung beschädigt werden.
- Legacy-M3U-URL-Lader validiert HTTP(S) und hat ein 30-Sekunden-Netzwerk-Timeout.
- Nächster geplanter Sprachblock: sprachabhängige Eingabe-/Tastaturunterstützung für de, tr, en, ru, pl, es, fr und ar; Smartphone-IME und Android-TV-D-pad-Eingabe getrennt berücksichtigen.

## Recovery 44 – Fehlerfeedback und Bedienung (09.11.2026)
- Downloadfehler bei Filmen, Episoden und Staffeln werden nicht mehr still verschluckt.
- Fehler beim Starten eines Streams werden sichtbar angezeigt.
- Neue Fehlermeldungen in Deutsch, Türkisch, Englisch, Russisch, Polnisch, Spanisch, Französisch und Arabisch.
- Fokusdarstellung der Episoden-Download-Aktion verbessert.
- Asynchrone Kindersperren-Initialisierung auf Screen-Lifecycle abgesichert.


## Recovery 45 – Diktierfunktion für Setup-Eingaben (09.11.2026)
- Wiederverwendbares sprachabhängiges Diktier-Eingabefeld ergänzt und in M3U-, EPG-, Xtream-Server- und Benutzername-Felder integriert.
- Erkennungssprache wird anhand der gewählten App-Sprache aus den auf dem Gerät verfügbaren Sprachmodellen gewählt (de, tr, en, ru, pl, es, fr, ar).
- Passwort bleibt bewusst ohne Diktierfunktion; erkannte Texte werden nicht automatisch verändert.
- Meldungen für Diktierfunktion und fehlende Sprachmodelle in allen acht Sprachen ergänzt.
- Eigene TV-Tastatur mit direktem Groß-/Kleinschreibungswechsel bleibt als nächster separater Arbeitsschritt offen.


## Recovery 46 – Eingabe-Workflow und URL-Vorschläge (09.11.2026)
- Xtream-Eingabefelder ausdrücklich ohne automatische Großschreibung konfiguriert; Passwort-Autokorrektur und Vorschläge deaktiviert.
- `VoiceInputField` um FocusNode, `TextInputAction` und `onSubmitted` erweitert.
- Direkt auswählbare `http://`- und `https://`-Vorschläge ergänzt; Schemawechsel bewahrt den restlichen Adresstext und verhindert doppelte Präfixe.
- Enter-/Weiter-Fokusfolge Server → Benutzername → Passwort → Verbinden umgesetzt.
- Keine Änderung an Authentifizierung, Playlist- oder Backendlogik.
- Flutter-Analyse, APK-Build und reale IME-/D-pad-Tests mangels SDK/Hardware offen. Details: `RECOVERY_46_HANDOFF_DE.md`.


## Recovery 47 – Playlist-Profile und Organisation (09.11.2026)
- Persönliche Anzeigenamen für M3U- und Xtream-Playlists im Setup ergänzt.
- Neues lokales Playlist-Profilmodell mit Ordnername, Sichtbarkeit, Aktiv-Markierung und Sortierreihenfolge.
- Playlist-Verwaltungsseite in Einstellungen ergänzt: Profile bearbeiten, Ordner zuweisen, ein-/ausblenden und sortieren.
- „Playlist hinzufügen“ führt in den Setup-Assistenten zurück zur Verwaltung.
- Lokalisierung für den neuen Bereich in allen acht Sprachen ergänzt.
- Aus Sicherheitsgründen werden in diesem Metadatenspeicher keine Serveradressen oder Passwörter abgelegt.
- Wichtige Grenze: Die vollständige Multi-Playlist-Laufzeitumschaltung und tatsächliche Filterung der Hauptnavigation folgen in einem separaten Architekturblock; diese Recovery speichert und verwaltet zunächst die Profileinstellungen.
- Test für Profil-Serialisierung und Aktiv-Markierung angelegt, mangels Flutter/Dart-SDK nicht ausgeführt.


## Recovery 48 – Sichere Quellenkonfiguration und Playlist-Aktivierung (09.11.2026)
- `PlaylistSourceConfig` und `PlaylistSourceStore` ergänzt; Remote-M3U-URLs und Xtream-Zugangsdaten liegen getrennt von Playlist-Metadaten in Android Secure Storage.
- Setup speichert wiederverwendbare Remote-M3U-/Xtream-Quellen nach erfolgreichem Import.
- `PlaylistSwitchService` lädt gespeicherte Remote-M3U- und Xtream-Quellen erneut; die bisherige Bibliothek wird erst nach erfolgreichem Abruf ersetzt.
- Playlist-Verwaltung kann gespeicherte sichtbare Profile aktivieren; Aktiv-Markierung folgt nach erfolgreichem Wechsel.
- Lokale M3U-Dateien sind in dieser Ausbaustufe noch nicht automatisch wiederladbar; Sichtbarkeitsfilterung in der Hauptnavigation folgt separat.
- Tests für Quellenkonfiguration und Aktivwechsel ergänzt. Flutter-Tests/Build mangels SDK nicht ausgeführt. Details: `RECOVERY_48_HANDOFF_DE.md`.

## Recovery 49 – Lokale M3U-Quellen wiederladbar (09.11.2026)
- `PlaylistSourceConfig` um `localFilePath` erweitert.
- Importierte lokale M3U-Dateien werden im privaten App-Dokumentenbereich gespeichert; Secure Storage hält nur die Dateireferenz.
- `PlaylistSwitchService` kann lokale M3U-Quellen erneut laden und verwendet dabei den stabilen Profil-`sourceKey`.
- Ausgeblendete Profile können weiterhin bewusst über die Playlist-Verwaltung aktiviert werden; Ausblenden ist kein Löschen.
- Playlist-Hinweise in allen acht Sprachen aktualisiert und JSON-Roundtrip-Test für lokale Quelldateireferenz ergänzt.
- Sichtbarkeitsfilterung der Hauptnavigation und parallele Bibliotheks-Caches bleiben offen. Flutter-Tests/Build mangels SDK nicht ausgeführt. Details: `RECOVERY_49_HANDOFF_DE.md`.

## Recovery 50 – Playlist-Quellnavigation im Dashboard (09.11.2026)
- Neue Dashboard-Komponente für Playlist-Quellen ergänzt.
- Sichtbare Playlist-Profile werden nach Ordner gruppiert und können per ExpansionTile auf- und zugeklappt werden.
- Aktive Quelle wird markiert; Quellwechsel nutzt den bestehenden PlaylistSwitchService mit Lade- und Fehlerfeedback.
- Ausgeblendete Profile werden aus der normalen Dashboard-Quellnavigation herausgefiltert, bleiben aber in der Verwaltung erhalten.
- Neue Beschriftung in allen acht Sprachen ergänzt.
- Quellnavigation aktualisiert sich nach Rückkehr aus den Einstellungen; aktive Quelle wird mit dem tatsächlich geladenen ContentProvider abgeglichen.
- Dashboard-Raster, Abstände und Quellkarte für schmale Smartphone-Ansichten angepasst, TV-Raster bleibt auf großen Displays dreispaltig.
- Aktuell bleibt eine Inhaltsbibliothek zur selben Zeit im ContentProvider geladen; parallele Playlist-Caches sind noch offen. Flutter-Build/Hardwaretests mangels SDK und Geräten nicht möglich. Details: `RECOVERY_50_HANDOFF_DE.md`.

## Recovery 51 (09.11.2026)
- Playlist-Bibliothekscache (maximal drei Quellen) und Aktivierungstoken gegen veraltete asynchrone Ladeergebnisse.
- Cache-Schnellwechsel im PlaylistSwitchService, drei Regressionstests und Hand-off-Dokumentation.
- Flutter-Build und Gerätetests weiterhin nicht ausgeführt.

## Recovery 52 – atomarisierte Profiländerungen und Cache-Korrektur
- Serialisierte Playlist-Profil-Schreibzugriffe, korrigierte Cache-Grenze (aktive + zwei inaktive Bibliotheken), Statusanzeige aus geladenem ContentProvider, Schutz vor irreführenden Erfolgsmeldungen bei überholten Aktivierungen.
- Zwei zusätzliche Tests und präzisierter Cache-Test; mangels Flutter-SDK nicht ausgeführt. Siehe `RECOVERY_52_HANDOFF_DE.md`.

## Recovery 53 – 09.11.2026
- Inaktive Verlaufseinträge von Bibliotheksobjekten entkoppelt.
- Asynchrone Metadaten-Anreicherung gegen Playlist-Wechsel abgesichert.
- Quellenlistenfläche erweitert; zwei Isolationstests ergänzt.

## Recovery 54 – Android-TV-Tastatureingabe
- Neue D-Pad-fokussierbare Bildschirmtastatur für URL, Benutzername und Passwort.
- Acht Sprachalphabete, Umschalten Groß-/Kleinschreibung, URL-Sonderzeichen und Scheme-Tasten.
- Bestätigung/Abbruch ohne unbeabsichtigte Änderungen; Passwort verdeckt.
- Technische und Hardware-Tests stehen noch aus; Details in `RECOVERY_54_HANDOFF_DE.md`.

## Recovery 55 (09.11.2026)
- TV-Tastatur lokalisiert (8 Sprachen), RTL, responsive Scrollbereich, Fokus-Start, kein überlagerndes OS-IME; Widget-Test ergänzt.
- Flutter-/Gerätetests ausstehend.

## Recovery 56 (09.11.2026)
- Groß- und Kleinbuchstaben auf der TV-Tastatur direkt einzeln auswählbar, ohne Shift.
- Widget-Regressionstest für gemischte Eingabe ergänzt; Hardware- und Flutter-Tests weiterhin offen.

## Recovery 57 (09.11.2026)
- Stabiler Tastaturtasten-Fokus und automatisches Scrollen zur fokussierten Taste bei D-Pad-Navigation.
- Widget-Test für kompakte TV-Ansicht ergänzt; Flutter-Ausführung offen.

## Recovery 58 (09.11.2026)
TV-Tastatur: Escape-Abbruch, stabile Fokusziele für Abbrechen/Bestätigen, Eingabefeld aus Fokusnavigation, zwei Widget-Tests.

## Recovery 59
TV-Tastatur: feste Fokusreihenfolge, einheitliche Fokusgruppe und neuer Regressionstest. Flutter-Tests weiterhin ausstehend.

## Recovery 60
- D-Pad-Pfeiltasten steuern in der TV-Tastatur gezielt die räumliche Fokusnavigation.
- Regressionstest für Fokuswechsel ohne Texteingabe.

## Recovery 61
- D-Pad-Aktionsnavigation Links/Rechts, Hoch-Rücksprung zur letzten Tastaturtaste, Runter-Fallback; zwei Widget-Tests.
- Flutter-/Gerätetests weiterhin offen.

## Recovery 63 – 09.11.2026
- TV-Tastatur: URL-Protokoll-Schnelltasten korrigiert (kein doppeltes http/https).
- Zwei neue Widget-Tests und Übergabedokumentation.

## Recovery 65 (09.11.2026)
TV-Tastatur: bestätigte Eingaben führen zum nächsten Xtream-Feld; Passwortbestätigung fokussiert Verbinden. Zwei Widget-Tests ergänzt. Siehe RECOVERY_65_HANDOFF_DE.md.

## Recovery 66
Xtream-Serveradresse und Zugangsdaten vor Verbindungsaufbau validiert; Fehlerausgaben datensparsamer; Unit-Tests ergänzt.

## Recovery 67 – 09.11.2026
Xtream-Timeouts, selektive Wiederholungen, sichere Fehlertexte und drei Tests. Siehe RECOVERY_67_HANDOFF_DE.md.

## Recovery 68 – Player-Wiederverbindung
Begrenzte automatische Wiederverbindung, manuelle Retry-Schaltfläche, Generationsschutz, Fortschrittsfortsetzung und sichere Fehleranzeige.

## Recovery 69 (2026-11-09)
- Wiedergabe-Stillstandsmonitor und Mediatheken-Konzept.

## Recovery 70
- Reconnect-VOD-Position vor Media.open gesichert.
- Hintergrundbetrieb von Stillstandsüberwachung ausgenommen.
- Mediatheken-Rechteprüfung dokumentiert; keine Integration ohne Freigabe.

## Recovery 71
- Reconnect-Resume priorisiert, Fortschrittsabruf ausfallsicher, keine Hintergrund-Retry-Events; Mediatheken nicht implementiert.

## Recovery 72 – Buffering-Erkennung
Zeitlich begrenzte Buffering-Toleranz und Reset bei Wiederaufnahme; siehe RECOVERY_72_HANDOFF_DE.md.

## Recovery 73
Android-TV Player-Fokus: keine doppelte OK-Aktion; Steuerleiste bleibt bei fokussierten Buttons sichtbar.

## Recovery 74
- Fokusstart und Fokus-Rückkehr der Player-Navigation verbessert; Play/Pause-Fehlauslösung hinter Overlays verhindert; Drawer-Breite begrenzt.

## Recovery 75
- Scrollposition und Sichtbarkeit des aktuellen Senders bzw. der Episode in langen Player-Listen verbessert.
- Details: RECOVERY_75_HANDOFF_DE.md.


Recovery 76: Fokusabhängiges Scrollen in langen Sender-/Episodenlisten; siehe RECOVERY_76_HANDOFF_DE.md.

## Recovery 77
- D-Pad-Fokus-Scroll-Anforderungen entprellt; veraltete Requests bei Drawer-/Kategoriewechsel verworfen.

## Recovery 78
# Recovery 78 – Übergabe (09.11.2026)

Basis: Recovery 77. Schwerpunkt: zusammenhängende Stabilisierung der Android-TV-Player-Navigation.

Änderungen:
- Player-Steuerleiste wird aus der Fokusnavigation ausgeschlossen, solange Sender-, Episoden- oder Verlaufsdialoge geöffnet sind oder der Streamfehlerdialog aktiv ist.
- Fokusgruppen für die drei Player-Navigationsbereiche getrennt.
- Senderliste startet mit Fokus auf der Kategorie „Alle“; konkurrierenden Autofokus auf Senderzeilen entfernt.
- Nach Schließen von Sendernavigation und Verlauf kehrt der Fokus zur Player-Oberfläche zurück.
- Verlauf fokussiert beim Öffnen gezielt die Schließen-Taste.
- Episodenwechsel verwirft alte Scrollanforderungen und stellt Player-Fokus wieder her.
- Kategorie-Scrollcontroller und Fokusressourcen werden sauber freigegeben.
- Vier zusätzliche Regressionstests für Quellcode-Invarianten (keine ausgeführten UI-Tests).

WICHTIG: Eine vollständige Freigabe der gesamten Fernbedienungssteuerung ist ohne Flutter-Kompilierung und reale Android-TV-Tests nicht seriös möglich. Fokusarbeiten sind code-seitig gebündelt; verbleibende Freigabeschritte: flutter analyze, flutter test, Android TV D-Pad/Back/OK/long-list manuell prüfen.

Mediatheken: kein Modul implementiert; wie vereinbart aus dem aktiven Umfang ausgeschlossen.


## Recovery 79
- Android-TV-Launcher-Banner; korrekt benanntes Debug-Manifest; Release-Signierung ohne Debug-Fallback; APK-Testanleitung und strukturelle Prüfungen.

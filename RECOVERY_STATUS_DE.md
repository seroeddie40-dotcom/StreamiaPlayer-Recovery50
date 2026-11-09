Aktuelle gesicherte Entwicklungsbasis: **Recovery 80** (GitHub-Actions-Test- und Debug-APK-Pipeline; Flutter-Build noch nicht ausgeführt). Siehe `RECOVERY_80_HANDOFF_DE.md`.

Aktuelle Entwicklungsbasis: Recovery 79 (APK-/Android-TV-Build-Vorbereitung; nicht Flutter-kompiliert).

Aktuelle gesicherte Entwicklungsbasis: Recovery 77 (09.11.2026). Siehe RECOVERY_77_HANDOFF_DE.md.

Aktuelle gesicherte Basis: Recovery 73.

Aktuelle Arbeitsbasis: Recovery 71 (auf Recovery 70 aufgebaut).
Aktuelle Entwicklungsbasis: Recovery 70 (09.11.2026). Siehe RECOVERY_70_HANDOFF_DE.md.

AKTUELLER GESICHERTER STAND: Recovery 68 (Code strukturell geprüft, Flutter-Tests offen).

Aktueller Projektstand: Recovery 67 (09.11.2026). Siehe RECOVERY_67_HANDOFF_DE.md.

## Recovery 64 – URL-spezifische Android-TV-Tastatur
Nur URL-Felder zeigen Protokoll-Kürzel; Benutzername/Passwort nicht. Tests ergänzt, nicht ausgeführt.

AKTUELLER GESICHERTER STAND: Recovery 63 (09.11.2026)

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

Aktueller gesicherter Stand: Recovery 61 (09.11.2026). Flutter-/APK-Tests ausstehend.

Aktuelle gesicherte Basis: Recovery 60.
# Aktueller gesicherter Stand: Recovery 58

Siehe `RECOVERY_58_HANDOFF_DE.md`.

Aktuelle Entwicklungsbasis: Recovery 57.

AKTUELLER GESICHERTER STAND: Recovery 56 (09.11.2026)

## Aktueller Stand: Recovery 55 (09.11.2026)

Siehe RECOVERY_55_HANDOFF_DE.md. Flutter-/APK-Tests weiterhin offen.

Aktueller gesicherter Stand: Recovery 53 (09.11.2026).
Siehe RECOVERY_53_HANDOFF_DE.md.

# Streamia Player – Recovery-Status

Aktuelle Arbeitsgrundlage: **Recovery 51 (09.11.2026)**.

## Enthaltene Player-Bereiche
- Rechte Verlaufleiste mit drei vertikal angeordneten, einklappbaren Bereichen: 10 letzte Sender, 10 letzte Filme und 10 letzte Serienepisoden.
- Jeder Verlaufsbereich kann unabhängig und nach Sicherheitsabfrage gelöscht werden; die Löschung ist auf den jeweiligen Verlaufstyp der aktuell aktiven Playlist-Quelle begrenzt.
- Live-TV-Verlaufseinträge schalten direkt zum Sender.
- Film- und Serienepisoden-Verlaufseinträge bieten „Weiterschauen“, „Von vorne starten“ und „Abbrechen“.
- Serienstart von vorne beginnt bei der ausgewählten letzten Episode.
- Lokale Verlaufpersistenz mit Wiederverknüpfung an die aktuell geladene Playlist anhand `sourceKey` und Inhalts-ID.
- Linke Live-TV-Navigation mit Kategorien links und Sendern rechts.
- Linke Episodenliste für Serien.
- Untere Media-Steuerung mit Wiedergabe, Sprüngen, Audio-/Untertitelauswahl und Bildformatoptionen.
- Wiedergabefortschritt mit lokaler Offline-Warteschlange und periodischen Synchronisierungsversuchen.

## Recovery 28
- Rechte Verlaufleiste neu strukturiert: drei gestapelte Akkordeonbereiche statt horizontaler Tabs.
- Pro Bereich eigener Löschknopf, Eintragszähler und Sicherheitsabfrage.
- Serien-„Von vorne starten“ korrigiert: startet die ausgewählte Episode von Beginn an.

## Noch offen / ausdrücklich nicht verifiziert
- Das aktuelle `Channel`-Modell kennt nur ein `category`-Feld. Echte verschachtelte Ordner/Unterordner benötigen eine belegte Pfadstruktur aus den jeweiligen Playlist-Formaten und eine Erweiterung der Parser.
- Verlaufssynchronisierung über mehrere Geräte ist nicht umgesetzt.
- Fokus-Rückkehr nach Unterseiten ist zentral abgesichert; die vollständige D-pad-Bedienung muss weiterhin auf Android TV getestet werden.
- Audio-/Untertitelwechsel muss mit realen Streams und der installierten media_kit-Version geprüft werden.
- Flutter-Analyse, APK-Build und echte Geräteprüfungen wurden in dieser Umgebung nicht ausgeführt.
- Supabase-Migrationen wurden nicht live ausgeführt.

## Arbeitsumgebung
Kein Flutter-/Dart-SDK und keine Live-Supabase-Verbindung verfügbar. Statische Datei-/Import-/Konfigurationsprüfungen ersetzen keinen Build oder Gerätetest.

## Recovery 29 – aktueller Arbeitsstand

- Fernbedienungsnavigation im Player verbessert: Richtungstasten können bei sichtbarer Steuerleiste wieder für Fokuswechsel verwendet werden; Seek per Links/Rechts bleibt bei ausgeblendeter Steuerleiste aktiv.
- Verlaufs-Sidebar in eine eigene Fokus-Traversierungsgruppe gesetzt.
- Playlist-Bestandsaufnahme abgeschlossen: M3U `group-title` und Xtream `category_name` sind aktuell flache Kategorien. Es existiert noch kein verlässliches Kategorie-Baumformat in den eingelesenen Daten. Verschachtelte Ordner werden daher nicht aus möglicherweise bedeutungsvollen Kategorienamen geraten.
- Audio-/Untertitel-Track-Auswahl nutzt dynamische `media_kit`-Aufrufe. Mangels installiertem Flutter-/Dart-SDK und ohne reale Teststreams ist die API-/Gerätekompatibilität offen.
- Weiterhin keine Flutter-Analyse, APK-Erstellung, Android-Hardwaretests oder Live-Supabase-Tests möglich in dieser Umgebung.


## Recovery 30
- Serien-Detailansicht: eindeutiger initialer Episodenfokus nur am Anfang der ersten Staffel; Staffel-Episoden sind separat gruppiert.
- Audio-/Untertitelwechsel: Fehler beim Anwenden einer gewählten Spur werden jetzt sichtbar gemeldet.
- Die verwendete dynamische media_kit-Anbindung ist weiterhin nicht zur Laufzeit bestätigt.


## Recovery 31 – Audio-/Untertitelauswahl
- Dynamische Player-Aufrufe durch die typisierten media_kit-Methoden ersetzt.
- „Automatisch“ für Audio und Untertitel; „Aus“ für Untertitel; aktive Spur wird visuell markiert.
- Auto-/No-Platzhalter werden nicht doppelt als Streamspuren angezeigt.
- API-Signaturen mit offizieller media_kit-Dokumentation abgeglichen; kein lokaler Flutter-Build möglich.

## Recovery 34
- Dashboard-Kopfaktionen und Download-Aktionen in Film-/Serienübersichten für D-pad/Tastatur konsistenter fokussierbar.
- Weiterhin ausstehend: vollständiger Flutter-Analyse-/Buildlauf und reale Android-TV-/Fernbedienungstests.

## Recovery 35
- Sprachauswahl, Kindersperren-Ziffernblock/Ordneraktionen und Paywall-Auswahlflächen zeigen jetzt sichtbare D-pad-Fokuszustände.
- Nicht angemeldete Favoriten-Schaltfläche ist als deaktivierter, erklärter IconButton semantisch konsistenter.
- Kein Flutter-Analyse-/Buildlauf und keine realen Fernbedienungstests möglich; siehe `RECOVERY_35_HANDOFF_DE.md`.

## Recovery 36

- D-pad-Fokusführung in Weiterschauen, Favoritenbibliothek, Admin-Geräteverwaltung, Suche und Favoriten-Backup verbessert.
- Vollständiger Projektstand in `StreamiaPlayer_Recovery_36_2026-11-09.zip`.
- Kein Flutter-Analyse-/Buildlauf und keine realen Fernbedienungstests möglich; siehe `RECOVERY_36_HANDOFF_DE.md`.

## Recovery 37
- Player-Overlay, Verlauf, Episoden-/Kategorieauswahl und Dialogfokus für D-pad/Keyboard verbessert.
- Sicherer Anfangsfokus auf „Abbrechen“ in Bestätigungsdialogen.
- Vollständiges Projekt: `StreamiaPlayer_Recovery_37_2026-11-09.zip`.
- Kein Flutter-Analyse-/Buildlauf und keine realen Fernbedienungstests möglich; siehe `RECOVERY_37_HANDOFF_DE.md`.

## Recovery 38
- Login/Registrierung, verpflichtende rechtliche Bestätigung und Playlist-Setup für D-pad-/Tastaturbedienung weiter vereinheitlicht.
- Vollständiger Projektstand: `StreamiaPlayer_Recovery_38_2026-11-09.zip`.
- Statische Prüfungen und ZIP-Integrität; kein Flutter-Analyse-/Buildlauf und keine realen Fernbedienungstests möglich.


## Recovery 39
- Einstellungen für D-pad/Tastatur vereinheitlicht: Theme, Sprache, Disclaimer, Favoriten, Backup, Kindersperre, Admin-Einstieg und Abmelden mit sichtbaren Fokuszuständen.
- Sicherheitsabfrage vor dem Abmelden ergänzt; „Abbrechen“ erhält den Anfangsfokus.
- Admin-Geräteverwaltung: Popup-Menü für Gerätestatus fokussierbar gemacht; Sperren/Freigeben benötigt eine Bestätigung mit sicherem Anfangsfokus auf „Abbrechen“.
- Aktualisieren-Aktion in der Admin-Geräteverwaltung mit Tooltip und Fokuszustand ergänzt.
- Server-RPCs und Admin-Berechtigungsprüfung unverändert.
- Flutter-Analyse, APK-Build und echte Geräte-/Fernbedienungstests weiterhin offen.
- Vollständiger Projektstand: `StreamiaPlayer_Recovery_39_2026-11-09.zip`; Details siehe `RECOVERY_39_HANDOFF_DE.md`.


## Recovery 40 – Fokus-Rückkehr bei Unterseiten (09.11.2026)
- Zentrale Hilfsfunktion `pushWithFocusRestore` ergänzt: Sie merkt sich vor dem Öffnen einer Route das aktuell fokussierte Element und fordert nach dem Schließen der Unterseite den Fokus dorthin zurück, sofern das Element weiterhin existiert und fokussierbar ist.
- Dashboard, Einstellungen, Live-TV, Filme, Serien, Suche, Weiterschauen und Favoriten verwenden die abgesicherte Push-Navigation.
- Flutter-eigene Route-FocusScopes bleiben erhalten; die neue Funktion ergänzt deren Wiederherstellung, statt sie zu ersetzen.
- Keine Änderungen an Wiedergabe-, Playlist-, Authentifizierungs-, Zahlungs- oder Backendlogik.
- Hardwareprüfung (Android TV / D-pad) und Flutter-Build bleiben mangels SDK/Hardware offen.


## Aktueller Arbeitsstand – Recovery 41 (09.11.2026)
- Aktueller Checkpoint baut auf Recovery 40 auf.
- Fokus-/D-pad-Verbesserungen in Favoriten, Weiterschauen, Sprachsuche und Admin-Fehlerzuständen ergänzt.
- Details und Prüfgrenzen: `RECOVERY_41_HANDOFF_DE.md`.


## Aktueller Arbeitsstand – Recovery 42 (09.11.2026)
- Setup-Assistent, Kindersperre und Paywall für D-pad-/Fernbedienungsbedienung verbessert.
- Paywall-Abmeldung mit Bestätigungsdialog und sicherem Anfangsfokus auf „Abbrechen“.
- Statische Prüfungen und ZIP-Integrität erfolgreich; kein Flutter-/Dart-SDK und keine Android-TV-Hardware verfügbar.
- Details und manuelle Testliste: `RECOVERY_42_HANDOFF_DE.md`.

## Aktueller Arbeitsstand – Recovery 43 (09.11.2026)
- Setup-Assistent robuster bei fehlender WLAN-IP und fehlgeschlagenem optionalen QR-/LAN-Serverstart.
- Unicode-/UTF-8-Dateiimport verbessert, damit internationale Sendernamen erhalten bleiben.
- Timeout und URL-Prüfung im Legacy-M3U-URL-Lader ergänzt.
- Sprach-Tastatur-Unterstützung für alle acht Sprachen als ausdrücklich gewünschter nächster Funktionsblock dokumentiert; Umsetzung folgt nach Abschluss der Fernbedienungs-/Bedienungsprüfung.
- Kein Flutter-/Dart-SDK und keine Gerätehardware für Build-/Laufzeittests verfügbar; Details siehe `RECOVERY_43_HANDOFF_DE.md`.

## Aktueller Arbeitsstand – Recovery 44 (09.11.2026)
- Film-, Episoden- und Staffel-Downloadfehler sowie Streamstartfehler werden verständlich und in der jeweils ausgewählten App-Sprache gemeldet.
- Kindersperren-Initialisierung gegen `setState` nach Screen-Dispose abgesichert.
- Neue Meldungsschlüssel in allen acht Sprachdateien ergänzt.
- Statische Prüfung: 50 Dart-Dateien, 8 JSON-Dateien, 153 relative Referenzen ohne fehlende Ziele.
- Kein Flutter-/Dart-SDK und keine Gerätehardware für Build-/Laufzeittests verfügbar; Details siehe `RECOVERY_44_HANDOFF_DE.md`.


## Recovery 45 – Diktierfunktion für Setup-Eingaben (09.11.2026)
- Wiederverwendbares `VoiceInputField` ergänzt; Sprache wird passend zur App-Sprachauswahl aus den auf dem Gerät verfügbaren Erkennungssprachen gewählt.
- Diktierfunktion für M3U-URL, EPG-URL, Xtream-Serveradresse und Xtream-Benutzername integriert; Passwort bleibt aus Datenschutzgründen ohne Mikrofonfunktion.
- Neue Meldungen für Diktat und nicht verfügbare Sprachmodelle in allen acht Sprachen.
- Erkanntes Diktat wird unverändert zur Prüfung übernommen; keine riskante automatische URL-Umformung.
- Noch offen: eigene Android-TV-Tastatur mit direkter Groß-/Kleinschreibung pro Buchstabe und vollständige IME-/Sprachtests auf Geräten.
- Kein Flutter-Analyse-/APK-Build und keine realen Mikrofon-/Android-TV-Tests mangels SDK/Hardware. Details: `RECOVERY_45_HANDOFF_DE.md`.


## Aktueller Arbeitsstand – Recovery 46 (09.11.2026)
- Xtream-Server, Benutzername und Passwort starten ohne automatische Großschreibung; Passwort-Autokorrektur und Vorschläge sind deaktiviert.
- Direkt auswählbare `http://`- und `https://`-Vorschläge oberhalb des Serverfelds; vorhandene Schemas werden beim Wechsel ersetzt statt verdoppelt.
- Enter/„Weiter“ führt Server → Benutzername → Passwort → Verbinden-Schaltfläche.
- `VoiceInputField` unterstützt jetzt Fokussteuerung und Eingabeaktionen, ohne bestehende Aufrufer zu brechen.
- Details und Prüfgrenzen: `RECOVERY_46_HANDOFF_DE.md`.


## Recovery 47 – Playlist-Profile und Organisation
- Setup-Felder für frei wählbare M3U-/Xtream-Playlistnamen ergänzt.
- Lokales Profilregister speichert Namen, Ordner, Sichtbarkeit, Aktiv-Status und Sortierung; keine Zugangsdaten oder URLs.
- Verwaltungsseite unter Einstellungen: umbenennen, Ordner zuweisen, ein-/ausblenden, Reihenfolge ändern und neue Playlist hinzufügen.
- Lokalisierung in acht Sprachen ergänzt.
- Die tatsächliche Multi-Source-Umschaltung und Anwendung von Sichtbarkeit/Ordnern in der Inhaltsnavigation ist noch offen; derzeit bleibt eine Inhaltsbibliothek gleichzeitig aktiv. Sichere Speicherung/Neuladen von Xtream-Konfigurationen muss vor automatischem Quellenwechsel umgesetzt werden.
- `test/playlist_profile_test.dart` ergänzt, aber ohne Flutter/Dart-SDK nicht ausgeführt.


## Recovery 48 – sichere Quellenkonfiguration und Aktivierung
- Remote-M3U-URLs sowie Xtream-Serveradresse, Benutzername und Passwort werden getrennt von den Profil-Metadaten in Android Secure Storage gespeichert.
- Remote-M3U- und Xtream-Profile können über die Playlist-Verwaltung erneut geladen und aktiviert werden.
- Der aktive `sourceKey` bleibt bei M3U-Refreshes stabil; der aktive Profilstatus wird nach erfolgreichem Laden aktualisiert.
- Lokale M3U-Dateien können noch nicht automatisch erneut geladen werden; die tatsächliche Ordner-/Sichtbarkeitsfilterung in der Hauptnavigation und isolierte parallele Bibliotheks-Caches stehen noch aus.
- Keine Flutter-Analyse, Tests, APK-Builds oder Hardwaretests mangels SDK/Hardware. Details: `RECOVERY_48_HANDOFF_DE.md`.


## Recovery 49 – lokale M3U-Quellen
- Importierte lokale M3U-Dateien werden im privaten App-Speicher abgelegt und können über die Playlist-Verwaltung erneut aktiviert werden.
- Die sichere Quellenkonfiguration speichert nur den Dateipfad, nicht den Playlist-Inhalt im Profil-Metadatenspeicher.
- Ausgeblendete Profile bleiben in der Verwaltung manuell aktivierbar; die Filterung der Hauptnavigation ist noch offen.
- 57 Dart-Dateien, 113 relative Imports/Exports/Parts ohne fehlende Ziele; acht Sprachdateien und YAML-Konfigurationen statisch geprüft.
- Kein Flutter-/Dart-SDK: kein `flutter analyze`, `flutter test` oder APK-Build; Hardwaretests offen.


## Recovery 50 – Playlist-Quellnavigation im Dashboard
- Sichtbare Playlist-Profile werden im Dashboard nach zugewiesenen Ordnern gruppiert.
- Ordner sind auf-/zuklappbar; aktive Playlist ist markiert und kann aus dem Dashboard gewechselt werden.
- Ausgeblendete Playlists erscheinen nicht in der normalen Dashboard-Quellnavigation, bleiben aber in der Playlist-Verwaltung erhalten.
- Alle acht Sprachen enthalten die neue Beschriftung.
- Der ContentProvider hält weiterhin eine aktive Bibliothek; parallele Caches je Playlist sind offen.
- Dashboard-Quellnavigation wird nach Rückkehr aus den Einstellungen aktualisiert und zeigt den aktiven Eintrag anhand des tatsächlich geladenen `sourceKey`.
- Dashboard-Layout und Quellkarte passen sich schmalen Smartphone-Displays an; breite TV-Layouts behalten drei Kachelspalten.
- Statische Prüfung: 8 Sprachdateien und YAML-Konfigurationen valide, 119 relative Referenzen ohne fehlende Ziele. Kein Flutter-Build/Hardwaretest mangels SDK/Hardware.
- Vollständiger Projektstand: `StreamiaPlayer_Recovery_50_2026-11-09.zip`; Details siehe `RECOVERY_50_HANDOFF_DE.md`.

## Recovery 51 – Playlist-Bibliothekscache und Schutz vor verspäteten Ladevorgängen
- In-Memory-Cache für bis zu drei Bibliotheken, schnelles Zurückschalten auf zuvor geladene Quellen.
- Aktivierungstoken schützt vor verspäteten M3U-/Xtream-Ergebnissen.
- Drei neue Flutter-Tests geschrieben, jedoch nicht ausgeführt (Flutter-SDK fehlt).
- Details und offene Grenzen: `RECOVERY_51_HANDOFF_DE.md`.

## Recovery 52 – atomarisierte Profiländerungen und Cache-Korrektur
- Serialisierte Playlist-Profil-Schreibzugriffe, korrigierte Cache-Grenze (aktive + zwei inaktive Bibliotheken), Statusanzeige aus geladenem ContentProvider, Schutz vor irreführenden Erfolgsmeldungen bei überholten Aktivierungen.
- Zwei zusätzliche Tests und präzisierter Cache-Test; mangels Flutter-SDK nicht ausgeführt. Siehe `RECOVERY_52_HANDOFF_DE.md`.

## Recovery 59
TV-Tastatur: feste Fokusreihenfolge, einheitliche Fokusgruppe und neuer Regressionstest. Flutter-Tests weiterhin ausstehend.

## Recovery 65 (09.11.2026)
TV-Tastatur: bestätigte Eingaben führen zum nächsten Xtream-Feld; Passwortbestätigung fokussiert Verbinden. Zwei Widget-Tests ergänzt. Siehe RECOVERY_65_HANDOFF_DE.md.


Aktuelle Basis: Recovery 66. Xtream-Eingabeprüfung ergänzt; Flutter-Build und Hardwaretests weiterhin offen.


Recovery 76: Fokusabhängiges Scrollen in langen Sender-/Episodenlisten; siehe RECOVERY_76_HANDOFF_DE.md.


Aktueller Stand: Recovery 78 (siehe RECOVERY_78_HANDOFF_DE.md).

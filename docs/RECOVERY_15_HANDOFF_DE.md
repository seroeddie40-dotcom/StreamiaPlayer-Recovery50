# Recovery 15 – Wiedergabefortschritt und Weiterschauen

## Neu in diesem Stand
- Neue `WatchProgressService` für kontobasierte Wiedergabepositionen.
- VOD- und Serienepisoden-Fortschritt wird während der Wiedergabe alle 15 Sekunden gespeichert und beim erneuten Öffnen wiederhergestellt.
- Serienepisoden werden mit einer stabilen zusammengesetzten Kennung `seriesId::episodeId` gespeichert, damit das zuletzt gesehene Kapitel auf einem anderen Gerät wiedergefunden werden kann.
- Live-TV wird bewusst nicht als zeitbasierter Resume-Eintrag gespeichert.
- Neue Ansicht „Weiterschauen“ mit Fortschrittsbalken und Resume-Aktion für aktuell geladene Playlist-Inhalte.
- Neue Dashboard-Kachel; Beschriftungen und Leer-/Fehlerzustände sind in allen acht App-Sprachen vorhanden.
- Neue Supabase-Migration `202611080004_watch_progress_sync.sql`: `source_key`, Bereinigung vorhandener Dubletten, eindeutiger Index und Benutzer-RLS.

## Daten- und Datenschutzregeln
- Gespeichert werden Benutzer-ID (RLS-gebunden), Quellen-Fingerprint, Inhalts-ID/-Typ, Titel, Position, Dauer und Zeitstempel.
- Keine Playlist-URL, Stream-URL, Benutzername oder Passwort wird in der Wiedergabehistorie gespeichert.
- Fortschrittssynchronisierung ist Best-Effort: fehlende Verbindung oder noch nicht ausgeführte Migration darf die Wiedergabe nicht blockieren.
- Auf einem neuen Gerät muss die entsprechende Playlist weiterhin vom Nutzer selbst eingebunden werden. Danach kann Streamia den gespeicherten Fortschritt anhand der Quellen- und Inhaltskennung zuordnen.

## Noch offen / Grenzen
- Die Migration muss in Supabase ausgeführt werden; bis dahin schlagen Cloud-Lese-/Schreibversuche still fehl und die Wiedergabe läuft weiter.
- Es wurde keine Offline-Warteschlange für Fortschrittsupdates implementiert. Fortschritt während längerer Offline-Zeit kann daher verloren gehen.
- Bei M3U-Playlists kann eine geänderte Quellenkennung (z. B. wesentlich veränderte Playlist) dazu führen, dass ein alter Fortschritt nicht automatisch zugeordnet wird.
- Der echte Mehrgeräte-Resume-Test, Flutter-Analyse, Flutter-Tests und APK-Build sind noch auszuführen.
- Serienfortschritt wird pro Episode gespeichert; die Liste zeigt die zuletzt fortgesetzten Episoden, nicht eine aggregierte Serienkarte.

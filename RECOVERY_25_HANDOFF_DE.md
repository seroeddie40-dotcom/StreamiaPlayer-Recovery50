# Streamia Player – Recovery 25

## Änderungen
- Film-Auswahl aus dem rechten Verlauf: bei vorhandenem Fortschritt Dialog „Weiterschauen“ / „Von vorne starten“ / „Abbrechen“.
- Serien-Auswahl aus dem rechten Verlauf: zuletzt gespeicherte Episode wird anhand `seriesId::episodeId` in den jüngsten Wiedergabefortschritten der aktuellen Quelle gesucht.
- Fortsetzen öffnet die passende Episode und stellt deren Position über den bestehenden WatchProgressService wieder her.
- Von vorne starten setzt bei Film/Serie die automatische Wiederherstellung für diesen Start aus.
- Ohne gespeicherten Fortschritt startet der Inhalt ohne zusätzlichen Dialog.

## Datenschutz / Grenzen
- Keine Stream-URLs oder Playlist-Zugangsdaten werden durch diese Änderung neu gespeichert.
- Die Abfrage benötigt angemeldeten Supabase-Benutzer und die bereits vorgesehene `watch_history`-Migration. Ohne Cloud-Fortschritt startet der Inhalt von vorne.
- Flutter/Dart SDK, Android-Gerät und Live-Supabase-Verbindung standen für Build-/End-to-End-Tests nicht zur Verfügung.

## Nächster Schritt
- Untere Player-Steuerung mit Audio-/Untertitelspur-Auswahl und Bildformatsteuerung gegen die tatsächlichen media_kit APIs prüfen und implementieren.

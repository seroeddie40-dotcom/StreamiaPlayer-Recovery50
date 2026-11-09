# Streamia Player – Recovery 14 Übergabe

Diese Version baut auf Recovery 13 auf.

## Neue Funktionen / Korrekturen
1. Favoriten können aus der Favoritenbibliothek geöffnet werden, sofern die zugehörige Playlist aktuell geladen ist.
2. Live-Favoriten starten den Player; Film- und Serienfavoriten öffnen die jeweilige Detailansicht.
3. Bei abweichender oder nicht geladener Quelle zeigt Streamia einen Hinweis, statt falsche Inhalte zu öffnen.
4. Backup-Import ist gegen sehr große Dateien und überlange Felder begrenzt.
5. Abgebrochene Exporte werden still als Abbruch behandelt.

## Wichtige Grenzen
- Favoriten enthalten bewusst keine Stream-URLs oder Playlist-Zugangsdaten.
- Für Wiedergabe auf einem neuen Gerät muss der Nutzer seine eigene Quelle dort erneut hinzufügen. Die Favoriten werden danach über Quellkennung und Inhalts-ID zugeordnet.
- Die Supabase-Migration `202611080003_account_favorites_sync.sql` muss noch ausgeführt werden.
- Flutter-Analyse, Android-Build und Live-Supabase-Tests wurden nicht ausgeführt.

# Streamia Player – Supabase-Datenbank einrichten

## Schritt-für-Schritt

1. Öffne https://supabase.com/dashboard und wähle dein Projekt `Streamia-Player`.
2. Öffne links **SQL Editor**.
3. Klicke auf **New query**.
4. Öffne die Datei `supabase/migrations/202611070001_streamia_initial_schema.sql` aus diesem ZIP mit einem Texteditor.
5. Markiere den gesamten SQL-Inhalt und kopiere ihn.
6. Füge ihn in den SQL Editor von Supabase ein.
7. Klicke auf **Run** und warte auf die Erfolgsmeldung.
8. Öffne **Table Editor** und prüfe, ob `profiles`, `devices`, `playlists`, `user_settings`, `favorites`, `watch_history` und `entitlements` vorhanden sind.
9. Falls eine Fehlermeldung erscheint, führe nicht einzelne Teile auf eigene Faust aus. Sende mir den vollständigen Fehlertext oder einen Screenshot ohne persönliche Daten.

## Was damit eingerichtet wird
- Neue Supabase-Auth-Konten erhalten automatisch ein Profil und einen Free-Entitlement-Datensatz.
- Row Level Security (RLS) ist für alle Tabellen aktiviert.
- Nutzer können nur ihre eigenen Profile, Geräte, Playlist-Metadaten, Einstellungen, Favoriten und Wiedergabeverläufe lesen bzw. bearbeiten.
- Entitlements können von der App gelesen, aber nicht selbst auf Premium geändert werden.

## Noch nicht enthalten
- Diese Migration verbindet die Flutter-Bildschirme noch nicht automatisch mit den Tabellen.
- Die bestehende lokale Demo-Anmeldung muss noch durch echte Supabase-Authentifizierung ersetzt werden.
- Xtream-Passwörter, Tokens und private Playlist-URLs werden absichtlich nicht in diesen Tabellen gespeichert. Dafür entwickeln wir einen verschlüsselten serverseitigen Credential-Speicher.
- Es gibt noch keine echte Zahlungsabwicklung oder automatische Premium-Freischaltung.
- Geräte-Limits müssen später durch eine vertrauenswürdige Edge Function durchgesetzt werden.

## Vorsicht bei bestehenden Daten
Wenn du bereits Tabellen mit diesen Namen hast, führe die Migration nicht blind aus. Sende mir zuerst einen Screenshot der Tabellenliste (ohne persönliche Daten).

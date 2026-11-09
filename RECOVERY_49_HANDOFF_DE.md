# Streamia Player – Recovery 49 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 48. Projektname bleibt **Streamia Player**.

## Lokale M3U-Quellen wiederladbar gemacht
- `PlaylistSourceConfig` unterstützt jetzt zusätzlich `localFilePath`.
- Importierte lokale M3U-Inhalte werden nach erfolgreichem Parsen im privaten App-Dokumentenbereich unter `streamia_playlists/` abgelegt.
- Im Android Secure Storage wird nur der lokale Dateipfad zusammen mit der Quellkonfiguration hinterlegt; der Playlist-Inhalt wird nicht in SharedPreferences geschrieben.
- `PlaylistSwitchService` kann lokale M3U-Dateien erneut einlesen und mit dem stabilen Profil-`sourceKey` laden.
- Fehlende/gelöschte lokale Dateien führen zu einer verständlichen Wiederimport-Meldung statt zu einem stillen Wechsel.

## Verwaltung ausgeblendeter Profile
- Ausgeblendete Profile bleiben in der Playlist-Verwaltung sichtbar und können dort manuell aktiviert werden.
- Die Sichtbarkeitseinstellung ist ausdrücklich eine spätere Navigations-/Auswahlfilterung und kein Lösch- oder Sperrmechanismus.
- Hinweis- und Sicherheitstexte in allen acht Sprachen aktualisiert.

## Tests / statische Prüfung
- Test für JSON-Roundtrip einer lokalen M3U-Quellkonfiguration ergänzt.
- 57 Dart-Dateien erfasst.
- 113 relative Import-/Export-/Part-Verweise geprüft, keine fehlenden Ziele.
- Alle acht Sprach-JSON-Dateien erfolgreich geparst; die aktualisierten Playlist-Hinweise sind vorhanden.
- `pubspec.yaml` und `analysis_options.yaml` erfolgreich geparst.
- Profil-Metadatenmodell enthält weiterhin keine Serveradresse, M3U-URL oder Passwörter.

## Grenzen dieser Ausbaustufe
- Lokale M3U-Dateien sind nun erneut ladbar; das Löschen/Ersetzen eines Profils mit sicherer Bereinigung seiner lokalen Quelldatei ist noch nicht implementiert.
- Sichtbare Playlist-Profile und Ordner sind noch nicht in die Hauptnavigation integriert; die Sichtbarkeitspräferenz wirkt derzeit in der Verwaltungsoberfläche und ist für die nächste Navigationsausbaustufe vorbereitet.
- Die App hält weiterhin nur eine aktive Inhaltsbibliothek gleichzeitig; getrennte parallele Caches je Playlist sind noch offen.
- Keine Flutter-/Dart-SDK-Umgebung: `flutter analyze`, `flutter test` und APK-Build nicht ausgeführt.
- Keine Android-/Android-TV-Hardwaretests und keine Live-Supabase-Tests.

## Nächste Schritte
1. Sichtbare Profile und Ordner als Quellen-/Playlist-Navigation integrieren; ausgeblendete Quellen dort ausfiltern.
2. Pro Playlist Favoriten, Verlauf und Wiedergabefortschritt auf stabile Quellidentität prüfen.
3. Mehrere unabhängige Bibliotheks-Caches bzw. robustes Umschalten zwischen Quellen fertigstellen.
4. Danach die eigene Android-TV-Tastatur mit acht Sprachlayouts entwickeln.

# Streamia Player – Recovery 48 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 47. Projektname bleibt **Streamia Player**.

## Mehrfach-Playlist: sichere Quellenkonfiguration und Aktivierung

- Neues Modell `PlaylistSourceConfig` für getrennte Quellendaten ergänzt.
- Neues `PlaylistSourceStore` nutzt `flutter_secure_storage` (Android encrypted shared preferences) und hält M3U-Remote-URLs sowie Xtream-Serveradresse, Benutzername und Passwort getrennt vom Profil-Metadatenspeicher.
- Setup speichert nach erfolgreichem Laden die wiederverwendbare Remote-M3U-URL bzw. Xtream-Zugangsdaten verschlüsselt.
- Neue `PlaylistSwitchService` lädt ein gespeichertes Remote-M3U-Profil oder eine Xtream-Quelle erneut und ersetzt die Inhaltsbibliothek erst nach erfolgreichem Abruf.
- Quellenwechsel behält den stabilen `sourceKey` des Profils bei, auch wenn eine Remote-M3U-Playlist ihren Inhalt verändert hat.
- Playlist-Verwaltung hat eine Aktivieren-Aktion; während des Ladens wird ein Fortschrittsindikator angezeigt. Ausgeblendete Profile lassen sich nicht versehentlich aktivieren, bleiben aber in der Verwaltung einblendbar.
- Aktiv-Markierung wird nach erfolgreichem Quellenwechsel im Profilregister aktualisiert.
- Aktivieren-/Sicherheitstexte für den Funktionsblock sind in allen acht Sprachen ergänzt bzw. aktualisiert.
- Tests für Source-Config-JSON-Roundtrip und expliziten Aktivwechsel ergänzt.

## Grenzen dieser Ausbaustufe
- Automatisches erneutes Laden ist für Remote-M3U-URLs und Xtream-Zugänge vorgesehen.
- Importierte lokale M3U-Dateien und per LAN übertragene M3U-Inhalte werden noch nicht dauerhaft als wiederladbare Quelle gespeichert; bei ihnen meldet die Aktivieren-Aktion, dass die Quelle erneut hinzugefügt werden muss.
- Die Ordner-/Sichtbarkeitsfilterung in der tatsächlichen Hauptnavigation ist noch nicht integriert. Profile werden weiterhin in der Verwaltungsseite organisiert.
- Die lokale Inhaltsbibliothek bleibt ein aktiver Datensatz. Vollständige parallele Bibliotheks-Caches und isolierte Datenbanken pro Playlist sind noch nicht umgesetzt.
- Zugangsdaten werden nicht in SharedPreferences gespeichert. Secure Storage hängt von Android Keystore/Plugin-Verfügbarkeit ab.

## Statische Prüfung
- Alle acht Sprach-JSON-Dateien geparst.
- Neue Übersetzungsschlüssel in allen acht Sprachdateien vorhanden.
- Import-/Export-/Part-Verweise sowie YAML-Konfiguration geprüft.
- ZIP-Integrität geprüft.

## Prüfgrenzen
- Flutter-/Dart-SDK nicht verfügbar: `flutter analyze`, `flutter test` und APK-Build nicht ausgeführt.
- Keine Android-/Android-TV-Hardware für Secure-Storage-, Netzwerk- oder D-pad-Tests verfügbar.

## Nächste Schritte
1. Lokale M3U-Dateien sicher und wiederladbar verwalten.
2. Sichtbare Profile und Ordner in die Quellen-/Hauptnavigation integrieren; ausgeblendete Profile dort vollständig ausblenden.
3. Pro Quelle Favoriten, Verlauf und Wiedergabefortschritt konsistent isolieren und testen.
4. Danach die eigene Android-TV-Tastatur mit acht Sprachlayouts weiterentwickeln.

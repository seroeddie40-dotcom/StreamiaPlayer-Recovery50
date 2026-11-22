# Streamia Player – Phase 27.5: rekonstruierter Projektstand
Stand: 21.11.2026 (Wiederherstellung nach Chatwechsel)

## Tatsächlich im ZIP vorhanden
- Vollständige Projektbasis vom 21.11.2026, 13:31 UTC.
- Drei separat gesicherte neuere Dateien eingesetzt: player_screen.dart (13:33), vod_screen.dart (14:02), series_screen.dart (14:21 UTC).
- favorites_library_screen.dart: Berechtigungsprüfung für den ersten ID-Treffer an Öffnungslogik angeglichen.
- XMLTV-EPG-Modell, Parser, begrenzter URL-Cache, 12h-TV-Ansicht in vier 3h-Zeilen, mobile Programmliste, gemeinsames Panel ergänzt.
- Player zeigt EPG bei eingeblendeter Live-TV-Bedienleiste, sofern Sender-ID und konfigurierte XMLTV-URL vorhanden sind; keine zweite Videodecoder-Instanz.
- tool/check_phase27_5_favorite_authorization.py als neuer Quellcode-Vertragstest.

## Nicht als wiederhergestellt behaupten
- Die originalen letzten Stunden der temporären Arbeitskopie sind nicht verfügbar; diese Rekonstruktion ist nicht bytegleich.
- Die zweite, im abgebrochenen Chat erwähnte EPG-Korrektur ist unbekannt und nicht als exakt rekonstruiert markiert.
- Eine vollständige TV-Dreispalten-Neugestaltung, alle Long-OK-Favoritenwege und eine vollständige Achtsprachen-EPG-Lokalisierung sind nicht nachgewiesen.
- Live-Kindersperren-/Supabase-Synchronisierung auf Geräten, Performance und TV-Ruckeln sind nicht verifiziert.

## Prüfstatus
- 11/11 neue Quellcode-Vertragsprüfungen bestanden; diese prüfen Textverträge, nicht Kompilierung oder Laufzeit.
- Flutter/Dart-SDK in dieser Arbeitsumgebung nicht vorhanden: flutter analyze, flutter test, APK-Build nicht durchgeführt.
- Keine TV- oder Smartphone-Gerätetests durchgeführt.
- EPG ist aktuell auf XMLTV-URL-Quellen ausgerichtet; Xtream-spezifische EPG-API-Integration offen.

## Vorgehen
Vor Austausch der GitHub-Dateien zuerst Flutter analyze/test/build in CI und TV-/Mobile-Tests durchführen.
Dies ist ein zusammengeführter, nachvollziehbarer Wiederherstellungsstand, keine Produktionsfreigabe.

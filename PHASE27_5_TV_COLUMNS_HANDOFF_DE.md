# Streamia Player – Phase 27.5 – TV-Dreispaltenansicht

## Implementiert
- `lib/screens/live_tv_screen.dart`: TV-Layout mit Kategorie, Senderliste und metadatenbasierter Vorschau samt EPG.
- TV-Senderfokus aktualisiert die Auswahl; OK öffnet den Sender und prüft die Familienfreigabe erneut.
- EPG über `EpgRepository` und `PlaylistSourceStore`, kein zweiter Videodecoder.
- Mobile Grid und bestehende Kategorielogik bleiben im Quellcode erhalten.
- `tool/check_phase27_5_tv_columns.py`: 7 statische Vertragsprüfungen.

## Prüfstatus
- Vorhandene Phase-27.5-Vertragsprüfungen: 11/11 erfolgreich.
- Neue TV-Spalten-Quellcodeprüfungen: 7/7 erfolgreich.
- Flutter SDK in dieser Laufzeit nicht vorhanden: kein `flutter analyze`, kein `flutter test`, kein APK-Build.
- Kein TV-Gerätetest. Fokusgrenzen, EPG-Ladeverhalten, Scrollposition und UI-Performance müssen auf echter Hardware geprüft werden.
- Änderungen nur im ZIP, nicht in GitHub.

## Bekannte Grenzen
- Die Vorschau zeigt absichtlich kein laufendes Video, um einen zweiten Decoder zu vermeiden.
- EPG-XMLTV-Quelle muss in der Playlist konfiguriert sein.
- Die Prüfskripte sind statische Verträge, keine vollständigen Widget- oder Integrationstests.
- Bei sehr langen Listen und schnellen Fokuswechseln ist der EPG-Abruf auf echter Hardware zu messen.

## Nächster Block
- TV-Fokuswechsel über alle drei Spalten, Rückkehrfokus und langes OK für Favoriten ohne zusätzliche Fokusstopps.

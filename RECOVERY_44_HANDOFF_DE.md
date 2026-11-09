# Streamia Player – Recovery 44 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 43. Der Projektname lautet **Streamia Player**.

## Änderungen in Recovery 44

### Bedienungs- und Fehlerfeedback
- Fehler beim Film-Download werden nicht mehr still verschluckt, sondern als lokalisierte Meldung angezeigt.
- Fehler beim Episoden-Download werden lokalisiert gemeldet.
- Staffel-Downloads laufen wie bisher über die Episodenliste; wenn mindestens ein Download fehlschlägt, erhält der Nutzer nach dem Durchlauf eine verständliche lokalisierte Meldung.
- Ein Fehler beim Öffnen eines Streams wird im Player sichtbar gemeldet, statt kommentarlos in einem leeren Playerzustand zu enden.
- Die Episoden-Download-Aktion hat einen sichtbaren D-pad-Fokuszustand und eine größere Trefferfläche.
- Die asynchrone Initialisierung der Kindersperre prüft vor `setState`, ob der Screen noch aktiv ist.

### Lokalisierung
Neue Meldungsschlüssel wurden in allen acht Sprachdateien ergänzt:
- `de`, `tr`, `en`, `ru`, `pl`, `es`, `fr`, `ar`
- `download_failed`
- `download_season_failed`
- `stream_load_failed`

## Statische Prüfung
- 50 Dart-Dateien erfasst.
- 8 Sprach-JSON-Dateien erfolgreich geparst.
- Alle drei neuen Meldungsschlüssel sind in allen acht Sprachen vorhanden.
- `pubspec.yaml` und `analysis_options.yaml` erfolgreich geparst.
- 153 relative Dart-Import-/Export-/Part-Verweise geprüft; keine fehlenden Ziele.
- ZIP-Integrität separat geprüft.

## Prüfgrenzen
- Kein Flutter-/Dart-SDK in der Arbeitsumgebung; `flutter analyze`, Tests und APK-Build nicht ausgeführt.
- Keine Android-/Android-TV-Hardware für reale Fernbedienungs- und IME-Tests verfügbar.
- Download- und Streamfehler-Meldungen müssen mit echten Geräten und fehlerhaften Netzwerkbedingungen getestet werden.

## Nächste Schritte
1. D-pad-/Fernbedienungs-Matrix für Dashboard, Listen, Detailseiten, Player und Dialoge abschließen.
2. Danach alle Texteingabefelder inventarisieren und die sprachabhängige Tastatur-/IME-Unterstützung für die acht App-Sprachen implementieren. Die System-IME darf nur bevorzugt werden; nicht installierte Tastatursprachen dürfen nicht als verfügbar vorgetäuscht werden. Android TV braucht eine gesonderte D-pad-Eingabelösung.

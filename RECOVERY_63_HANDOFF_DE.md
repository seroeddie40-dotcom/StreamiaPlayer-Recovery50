# Streamia Player – Recovery 63 (09.11.2026)

Basis: vollständiger Projektstand Recovery 62.

## Änderungen
- Android-TV-Tastatur: URL-Schnelltasten `http://` und `https://` erkennen bereits vorhandene Protokollpräfixe und ersetzen diese, statt eine doppelte URL zu erzeugen.
- Ein bislang schemafreier Hostname erhält das ausgewählte Präfix am Anfang.
- Host, Port, Pfad und Query bleiben beim Protokollwechsel unverändert.
- Zwei Widget-Regressionstests für URL-Schemawechsel und Hostnamen ohne Präfix ergänzt.

## Prüfung und Grenzen
- ZIP-Integrität, relative Dart-Dateiverweise, acht Sprach-JSON-Dateien und YAML-Konfiguration statisch geprüft.
- Flutter/Dart-SDK in dieser Umgebung nicht vorhanden; keine Kompilierung, kein Widget-Testlauf, keine APK und kein Android-TV-Hardwaretest möglich.
- Die neuen Widget-Tests sind Quellcode, nicht als bestanden zu verstehen.

## Nächste Schritte
- Auf echtem Android TV URL- und Xtream-Felder mit Fernbedienung prüfen.
- Flutter analyze/test und Android-APK-Build in einer Flutter-fähigen Umgebung ausführen.
- D-Pad-Randfälle und Passwort-Eingabefokus mit echten Geräten testen.

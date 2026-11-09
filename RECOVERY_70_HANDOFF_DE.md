# Recovery 70 – Übergabe (09.11.2026)

Basis: Recovery 69. Schwerpunkt: robustere Wiedergabewiederherstellung und Rechteprüfung Mediatheken.

## Codeänderungen
- Bei VOD-/Serien-Reconnects wird die Wiedergabeposition **vor** `Media.open()` gesichert, damit asynchrone Positions-Resets nicht zur Wiedergabe ab Sekunde 0 führen.
- Beim Wechsel in den Hintergrund wird die Stillstandsüberwachung ausgesetzt; bei Rückkehr wird ihr Zeitfenster zurückgesetzt.
- Keine direkte Mediathekenintegration implementiert.

## Rechtliche Produktentscheidung
ARD: nur einfache Verlinkung allgemein zulässig; kommerzielle Embeddings und Neu-Zusammenstellung nicht ohne Erlaubnis. ZDF: kommerzielle Einbettung ausdrücklich untersagt. BBC: kommerzielle Nutzung von Inhalten/Marken benötigt gesonderte Erlaubnis, BBC iPlayer geobeschränkt. Für alle weiteren Länder ist eine anbieterspezifische Prüfung nötig. **Keine direkte Integration ohne belastbare schriftliche Nutzungsfreigabe.**
Offizielle Quellen (Abruf 09.11.2026):
- https://www.ardmediathek.de/nutzungsbedingungen
- https://www.ard-digital.de/medienwissen/medienpolitik
- https://www.zdf.de/nutzungsbedingungen
- https://www.bbc.com/usingthebbc/terms-of-use (BBC Terms je nach Region)

## Validierung / Grenzen
ZIP-Struktur und Konfigurationsdateien können statisch geprüft werden. Flutter-/Dart-SDK steht hier nicht zur Verfügung, daher keine bestätigte Kompilierung, keine ausgeführten Flutter-Tests und kein APK-/Hardwaretest. Die Reconnect-Logik muss auf realen Streams getestet werden.

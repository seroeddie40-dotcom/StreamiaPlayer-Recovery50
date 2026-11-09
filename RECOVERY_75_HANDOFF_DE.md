# Streamia Player – Recovery 75

Basis: Recovery 74.

## Änderungen
- Senderliste und Episodenliste erhalten eigene ScrollController.
- Beim Öffnen der Player-Navigation wird die aktuelle Episode bzw. der aktuelle Sender in langen Listen in den sichtbaren Bereich gescrollt.
- Bei Kategorieänderungen wird die Senderliste zurückgesetzt und, sofern vorhanden, der aktive Sender wieder sichtbar gemacht.
- Beide ScrollController werden beim Schließen des Players freigegeben.
- Die Listen verwenden eine feste Zeilenhöhe für berechenbare Scrollpositionen und lazy rendering.

## Prüfstatus
- ZIP-Integrität und Konfigurationsdateien werden bei Archivierung geprüft.
- Flutter SDK nicht verfügbar; weder Kompilierung noch Widget-Tests oder Hardwaretests ausgeführt.
- Offene Prüfung: Fokus nach Scrollen auf echten Android-TV-Geräten und kleine Bildschirmhöhen.
- Mediatheken sind ausdrücklich nicht Teil der aktiven Entwicklungsplanung.

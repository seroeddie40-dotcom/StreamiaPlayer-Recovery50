# Phase 27.5 – OK/Zurück in Live-TV, Filmen und Serien

## Änderung
- `lib/screens/player_screen.dart`: OK auf der freien Player-Oberfläche öffnet bei Filmen und Serien die Bedienleiste, ohne die Wiedergabe zu pausieren. Live-TV behält das Ein-/Ausblenden der Bedienleiste.
- Bei fokussierten Schaltflächen wird OK weiterhin an das jeweilige Bedienelement weitergegeben.
- Touch auf Filme/Serien blendet die Leiste ein, ohne unnötiges setState, wenn sie schon sichtbar ist.
- Keine neue Decoderinstanz oder Playlist-Verarbeitung.
- Neue statische Prüfung: `tool/check_phase27_5_ok_controls.py`.

## Prüfstatus
Alle vorhandenen Phase-27.5-Quellcodeprüfskripte und die neue Prüfung in diesem Arbeitsblock erfolgreich ausgeführt. Es handelt sich um Quelltext-Vertragsprüfungen, nicht um Flutter-Analyse, Kompilierung, Widget- oder Gerätetests. Flutter SDK nicht in dieser Umgebung verifiziert. Android TV D-Pad und Smartphone-Touch weiterhin real testen.

## Nächster Schritt
Fokus auf echten Android-TV-Geräten testen, insbesondere OK bei eingeblendeten Controls und stufenweises Zurück; danach Performance auf Nokia Streaming Box 8000/8010 und TCL überprüfen.

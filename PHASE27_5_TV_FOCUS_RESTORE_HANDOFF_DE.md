# Phase 27.5 – Fokuswiederherstellung (21.11.2026)

Änderung: lib/screens/live_tv_screen.dart
- Pro Senderobjekt stabiler Fokus-Knoten, auch bei doppelten IDs.
- Rückkehr aus Player prüft Route, Quelle, Familienfreigaben und aktuelle Filter erneut.
- Gesperrter/entfernter Sender erhält keinen Fokus; falls vorhanden, wird erster erlaubter sichtbarer Sender gewählt.
- Kategorie- und Filterwechsel invalidieren alte Vorschau/EPG und Rückkehrziel.
- Kein zusätzlicher Videodecoder.

Prüfung: statische Quellcode-Vertragsprüfungen, siehe Tool-Ausgaben.
Flutter-Build, Widgettest und Android-TV-Gerätetest offen.
Keine GitHub-Änderungen.

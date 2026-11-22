# Streamia Player – Phase 27.5 – TV-EPG-Navigationsblock
Stand: 21.11.2026

## Implementiert
- `lib/widgets/tv_epg_timeline.dart`: Hoch/Runter sucht nur Programme in der tatsächlich benachbarten 3-Stunden-Zeile.
- Am Rand oder ohne geeignete Sendung wird die Richtungstaste nicht abgefangen.
- Fokusänderungen aktualisieren den sichtbaren Auswahlrahmen; Touch-Klick fordert Fokus an.
- Links/Rechts gibt am Listenrand weiterhin `ignored` zurück; keine zweite Decoderinstanz.

## Tests
- 11/11 vorhandene Quellcode-Vertragsprüfungen bestanden.
- Neue Navigation nicht durch Widgettests oder Flutter-Build validiert (Flutter SDK fehlt).
- Reale TV-/Smartphone-Tests offen.
- GitHub unverändert. Arbeitscheckpoint, keine Produktionsfreigabe.

## Nächster Block
Dreispaltige Live-TV-Navigation und Fokus-Integration mit Widgettests.

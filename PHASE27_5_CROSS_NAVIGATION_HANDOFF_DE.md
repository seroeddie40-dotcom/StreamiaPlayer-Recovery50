# Phase 27.5 – TV-D-Pad-Übergänge, Checkpoint

## Änderungen
- EPG-Auswahl wird bei aktualisierten Programmdaten auf gültige Indizes begrenzt.
- EPG, Kategorien, Senderliste und Vorschau sind in Fokus-Traversal-Gruppen gegliedert.
- Am EPG-Rand bleiben Pfeiltasten für übergeordnete Fokusnavigation freigegeben.
- Bestehender Dreispalten-Vertragstest an neue Widget-Verschachtelung angepasst.
- Kein zweiter Decoder und keine zusätzliche EPG-Abfrage eingeführt.

## Prüfstatus
- Alle sechs Phase-27.5-Quellcodeprüfskripte bestanden (58 Einzelprüfungen).
- Flutter analyze, Flutter widget test, Flutter build und Gerätetest NICHT durchgeführt; SDK fehlt.
- Stufenweises Zurück, Fokusziele über Spaltengrenzen und echtes D-Pad-Verhalten weiterhin auf TV testen.
- GitHub unverändert. Kein Produktionsfreigabestand.

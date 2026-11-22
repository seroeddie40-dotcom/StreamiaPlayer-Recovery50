# Streamia Player – Phase 27.5: Fokus-/EPG-Checkpoint

## Tatsächlich geändert
- `lib/widgets/tv_epg_timeline.dart`: Eigene Zeilenposition beim D-Pad-Fokus; über mehrere Drei-Stunden-Zeilen reichende Sendungen können nun zeilenweise durchlaufen werden, ohne in ihrer Startzeile festzuhängen. Fokusmarkierung berücksichtigt die gewählte Zeile. Touch-Auswahl setzt Zeilenposition.
- `lib/screens/live_tv_screen.dart`: Kategorienwechsel verwirft alte EPG-Auswahl und zugehörige Future, damit keine Daten der vorherigen Kategorie irreführend angezeigt werden.
- `tool/check_phase27_5_epg_focus.py`: Neun statische Regressionsverträge.

## Prüfung
- `tool/check_phase27_5_favorite_authorization.py`: 11/11 bestanden.
- `tool/check_phase27_5_epg_focus.py`: 9/9 bestanden.
- ZIP-Integrität: geprüft.
- Flutter analyze/test/build: nicht durchgeführt, SDK in Umgebung nicht verfügbar.
- Android-TV-D-Pad- und Lang-OK-Gerätetest: offen.

## Noch offen
- Langes OK für Favoriten in TV-Listen und durchgehende Fokuswiederherstellung nach Player-Rückkehr.
- Widgettests für Fokusnavigation und Senderwechsel; Flutter-Build und reale TV-Tests.
- Keine Änderungen an GitHub; keine Einzeldateien ersetzen.

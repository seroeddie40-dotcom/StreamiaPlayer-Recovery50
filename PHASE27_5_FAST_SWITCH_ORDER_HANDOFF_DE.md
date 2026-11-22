# Phase 27.5 – schneller Senderwechsel: Reihenfolge von Media3-Zuständen

## Änderung
`lib/services/tv_media3_controller.dart`: Eine verspätete initiale `snapshot`-Antwort darf einen bereits empfangenen neueren nativen `state`-Callback derselben Streamgeneration nicht überschreiben. Bei jedem neuen Open und bei Dispose wird die Markierung zurückgesetzt. Generation- und Mounted-Prüfungen bleiben bestehen. Keine zusätzlichen Timer oder Decoder.

## Prüfstatus
Statische Quellcodeprüfungen; Flutter SDK/Android-TV-Gerätetests nicht verfügbar. Eine reale Race-Condition-Simulation auf Hardware ist noch offen.

## Weiter offen
Schnelles Umschalten mit Fernbedienung auf Nokia/TCL, Media3-Decoderperformance, komplette Regressionen und Android-Build. GitHub wurde nicht aktualisiert. Dies ist ein Zwischenstand und kein freigegebener Gesamtblock.

Commit-Vorschlag: `Phase 27.5: Verspätete Media3-Snapshots beim Senderwechsel ignorieren`

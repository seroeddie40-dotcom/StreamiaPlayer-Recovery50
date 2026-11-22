# Phase 27.5 – native Media3-Senderwechsel serialisiert (Zwischenstand)

## Änderung
`lib/services/tv_media3_controller.dart`: Native `open`/`stop`-Aufrufe laufen über eine einzige Future-Warteschlange je PlatformView. Eine neuere Senderanforderung invalidiert sofort ältere Event-Generationen; noch nicht ausgeführte, überholte Aufrufe werden übersprungen. Ein Fehler in einer älteren Operation blockiert die Warteschlange nicht. Initialer Snapshot und Generationsschutz bleiben erhalten. Keine zusätzlichen Timer, Player oder Decoder.

## Grenzen
Eine bereits an Android übermittelte `open`-Anforderung kann nicht rückwirkend abgebrochen werden; eine neue Anforderung wird anschließend ausgeführt. Native Decoderwechsel können weiterhin erforderlich sein. Kein Nachweis tatsächlicher Performanceverbesserung ohne Hardwaretests.

## Tests
26 statische Prüfscripte (einschließlich 13 neuer Checks); kein Flutter SDK oder Android-TV-Gerät verfügbar. GitHub nicht aktualisiert.

## Weiter offen
Übergreifende Regression, Build, Nokia/TCL-Hardwaretest mit schnellem Zapping, Hintergrund/Rückkehr, Profile-Revoke und Decoderdiagnose. Gesamtblock noch nicht freigegeben.

Commit-Vorschlag: `Phase 27.5: Media3 Streamwechsel serialisieren und überholte Opens überspringen`

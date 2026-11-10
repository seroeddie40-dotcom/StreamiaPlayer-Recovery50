# Recovery 19 – Übergabe

## Neu: aktivere Offline-Fortsetzung
- Der Player versucht ausstehende Fortschrittsdaten jetzt alle 30 Sekunden erneut zu übertragen, solange der Player geöffnet ist.
- Beim Zurückkehren der App in den Vordergrund wird `flushPending()` ebenfalls ausgelöst.
- Beim Wechsel in `inactive`, `paused` oder `detached` wird der aktuelle Fortschritt gespeichert.
- Queue-Änderungen und Queue-Übertragungen laufen über eine serielle Operationswarteschlange, damit parallele Flush-/Queue-Schreibvorgänge keine neueren Einträge überschreiben.
- Vor dem Replay wird geprüft, ob der Queue-Eintrag zum aktuell angemeldeten Konto gehört. Nach einem Kontowechsel wird die Queue des vorherigen Kontos nicht in die Queue des neuen Kontos geschrieben.

## Grenzen
- Das ist keine garantierte Hintergrund-Synchronisierung, wenn Android die App beendet oder der Player nicht geöffnet ist. Für echte Hintergrundarbeit wäre später ein gezielter WorkManager-/Background-Task-Ansatz samt Android-Tests erforderlich.
- App-Lifecycle- und Reconnect-Verhalten muss auf echten Android-Geräten geprüft werden.
- Flutter/Dart SDK ist in der Arbeitsumgebung nicht verfügbar; kein Flutter-Build/Test und kein APK-Build behauptet.
- Supabase-Migrationen wurden nicht live ausgeführt.

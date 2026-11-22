# Phase 27.5 – Prüfung Android-TV-Lebenszyklus (Arbeitsstand)

- Android ruft gewöhnlich `onPause` und danach `onStop` auf. Bisher wurde der native Player zweimal gestoppt und die Streamgeneration zweimal erhöht.
- `suspendPlaybackForBackground()` verhindert doppelte Stop-/Generationswechsel innerhalb desselben Hintergrundübergangs. Nach `onResume` ist ein neuer Übergang möglich.
- Die URL-Endung `.m3u` ist kein eindeutiger HLS-Hinweis; nur `.m3u8` erzwingt anhand der Dateiendung HLS.
- Unverändert: kein automatischer Start im Hintergrund, kein zweiter Player, keine zusätzlichen Timer, keine Ausgabe von Stream-URLs.
- Statische Tests ersetzen keine Flutter-/Kotlin-Kompilierung und keine Tests auf Nokia/TCL.

# Phase 27.5 – verspätete native Ereignisse im Hintergrund

- Media3-Zustands- und Fehlereignisse werden ignoriert, solange die Flutter-Activity nicht im Vordergrund ist.
- Verhindert, dass bereits vor dem Pausieren eingereihte Events den UI-Wiedergabestatus nachträglich ändern.
- Bestehende Wiederaufnahme bei `resumed` bleibt unverändert; keine zusätzlichen Timer oder Decoder.
- Statischer Regressionstest: `tool/check_phase27_5_background_callback_guard.py`.
- Geräte-/Flutter-Buildtests stehen aus.

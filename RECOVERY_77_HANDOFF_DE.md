# Streamia Player – Recovery 77 (09.11.2026)

Basis: Recovery 76.

## Änderungen
- Schnelle D-Pad-Bewegungen in Sender-/Episodenlisten: Nur die neueste Fokus-Scroll-Anforderung wird nach dem Frame ausgeführt.
- Beim Schließen/Öffnen des Navigationsdrawers oder Wechsel der Senderkategorie werden veraltete Scroll-Anforderungen verworfen.
- Fokus-Scroll-Animation auf 90 ms verkürzt, damit schnelle Richtungswechsel weniger Scroll-Animationen überlagern.
- Bestehende Listen, Wiederverbindungslogik und Mediatheken-Entscheidung unverändert.

## Testgrenzen
Statische Dateiverweise, Konfigurationsdateien und ZIP-Integrität geprüft. Kein Flutter-/Dart-SDK verfügbar; kein Flutter-Test, APK-Build oder Gerätetest durchgeführt.

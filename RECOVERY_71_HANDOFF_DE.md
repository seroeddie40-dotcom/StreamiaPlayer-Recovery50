# Streamia Player – Recovery 71

Ausgangspunkt: Recovery 70. Keine Mediatheken-Integration, gemäß Produktentscheidung.

## Änderungen
- Bei Wiederverbindung von VOD/Serien hat die vor dem Neustart gesicherte Position Vorrang vor dem erstmaligen Abruf eines gespeicherten Fortschritts.
- Ein fehlgeschlagener Fortschrittsabruf unterbricht die Wiedergabe nicht mehr und verursacht keinen unnötigen Reconnect.
- Player-Fehlerevents während Hintergrundbetrieb lösen keinen automatischen Wiederverbindungsversuch aus.

## Prüfung
ZIP, Dart-Dateiverweise, Sprach-JSON und YAML werden beim Packen geprüft. Flutter-SDK ist nicht installiert: keine Kompilierung, kein Flutter-Test und kein APK-Build bestätigt.

## Weiter offen
Android-/Android-TV-Gerätetests, Live-Stream-Stillstandsmonitor (Positionszähler kann bei Live-Streams abweichen), Netzwechsel- und Resume-Tests.

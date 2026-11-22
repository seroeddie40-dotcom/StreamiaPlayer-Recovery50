# Phase 27.5 – Stufenweises Zurück (TV)

## Änderung
`lib/screens/player_screen.dart`: Beim Zurück aus der sichtbaren Bedienleiste wird der automatische Ausblendtimer gestoppt und der Fokus gezielt auf die Player-Oberfläche zurückgegeben. Reihenfolge bleibt: Drawer > Verlauf > Bedienleiste > Player verlassen.

EPG-Sendungsdetails verwenden bereits einen Flutter-Dialog mit Schließen-Schaltfläche. Dieser Dialog wird beim Zurück zuerst geschlossen, ohne den Sender zu wechseln. Keine Änderung am Videodecoder oder der Smartphone-Layoutlogik.

## Prüfstatus
Neue statische Prüfungen: siehe `tool/check_phase27_5_back_navigation.py`. Vorhandene statische Prüfscripte erneut ausführen. Kein Flutter SDK in dieser Umgebung; Flutter analyze, Widget- und Gerätetests offen. Die Dialog-/Zurück-Interaktion ist nur statisch geprüft.

## Nächster Schritt
Android-TV-Fernbedienung auf Nokia/TCL testen: EPG-Dialog > Overlay > Player; Fokus und Zurück-Taste auch nach mehrfacher Navigation; Android-Back-Gesten am Smartphone prüfen.

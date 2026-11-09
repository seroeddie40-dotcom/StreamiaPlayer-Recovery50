# Streamia Player – Recovery 69

Basis: Recovery 68. Neuer Wiedergabe-Stillstandsmonitor im Player. Alle 5 Sekunden wird geprüft, ob die Wiedergabeposition seit mindestens 35 Sekunden nicht vorgerückt ist. Pausierte Wiedergabe, laufende Wiederverbindung und VOD am Ende sind ausgenommen. Bei erkanntem Stillstand wird die vorhandene begrenzte Wiederverbindungslogik genutzt. Monitor wird beim Verlassen beendet.

Zusätzlich: MEDIATHEKEN_KONZEPT_DE.md dokumentiert eine spätere, rechtlich zurückhaltende Verknüpfung offizieller Mediatheken. Das Modul ist noch nicht implementiert.

Prüfgrenze: Kein Flutter-SDK in der Umgebung; keine Kompilierung, keine ausgeführten Widget-Tests, kein APK-/Hardwaretest. Stillstandserkennung auf echten Live-Streams unbedingt prüfen (manche Quellen melden Position unregelmäßig).

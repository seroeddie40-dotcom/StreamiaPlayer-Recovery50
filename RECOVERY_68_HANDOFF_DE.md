# Streamia Player – Recovery 68

Basis: Recovery 67.

## Änderungen
- Player beobachtet media_kit-Fehlerereignisse, ohne sensible Stream-URLs oder Serverfehler anzuzeigen.
- Bei Abbruch maximal zwei zeitversetzte automatische Wiederverbindungsversuche (2 bzw. 4 Sekunden).
- Manuelle, fernbedienbare Schaltfläche „Erneut versuchen“ nach Abbruch.
- Veraltete Ladeversuche werden durch Generationskennung ignoriert; Timer werden beim Schließen abgebrochen.
- Bei VOD/Serien versucht der Player nach Wiederverbindung an der letzten Position fortzusetzen.

## Grenzen
- Kein Flutter-SDK verfügbar: weder Kompilierung noch Widget- oder Hardwaretests ausgeführt.
- Automatische Wiederverbindung reagiert auf media_kit-Fehler, nicht auf jeden möglichen stillen Netzwerkstillstand.
- Statusmeldungen im Player sind derzeit deutsch; Lokalisierung ist noch offen.
- Reconnect auf echten Geräten und verschiedenen IPTV-Servern prüfen.

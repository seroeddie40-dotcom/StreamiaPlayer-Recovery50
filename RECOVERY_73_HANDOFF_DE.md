# Recovery 73 – Android-TV Player-Fokus

Basis: Recovery 72.

- Eigener Fokuspunkt für die Player-Oberfläche.
- Enter/OK wird nicht mehr als Play/Pause interpretiert, wenn eine sichtbare Steuerschaltfläche den Fokus hat; dadurch keine doppelte Aktion beim Betätigen einer Taste.
- Während eines Fehler-/Wiederverbindungsdialogs wird Play/Pause per OK nicht versehentlich ausgelöst.
- Automatisches Ausblenden der Steuerleiste unterbleibt, solange ein Bedienelement fokussiert ist; Fehlerdialoge bleiben sichtbar.
- Keine Mediatheken-Funktion integriert.

Prüfung: statische Projekt- und Archivprüfung. Flutter-SDK nicht installiert; Flutter analyze/test, APK und echte TV-Fernbedienung weiterhin offen.

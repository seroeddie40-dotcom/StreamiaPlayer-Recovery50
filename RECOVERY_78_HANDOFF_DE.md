# Recovery 78 – Übergabe (09.11.2026)

Basis: Recovery 77. Schwerpunkt: zusammenhängende Stabilisierung der Android-TV-Player-Navigation.

Änderungen:
- Player-Steuerleiste wird aus der Fokusnavigation ausgeschlossen, solange Sender-, Episoden- oder Verlaufsdialoge geöffnet sind oder der Streamfehlerdialog aktiv ist.
- Fokusgruppen für die drei Player-Navigationsbereiche getrennt.
- Senderliste startet mit Fokus auf der Kategorie „Alle“; konkurrierenden Autofokus auf Senderzeilen entfernt.
- Nach Schließen von Sendernavigation und Verlauf kehrt der Fokus zur Player-Oberfläche zurück.
- Verlauf fokussiert beim Öffnen gezielt die Schließen-Taste.
- Episodenwechsel verwirft alte Scrollanforderungen und stellt Player-Fokus wieder her.
- Kategorie-Scrollcontroller und Fokusressourcen werden sauber freigegeben.
- Vier zusätzliche Regressionstests für Quellcode-Invarianten (keine ausgeführten UI-Tests).

WICHTIG: Eine vollständige Freigabe der gesamten Fernbedienungssteuerung ist ohne Flutter-Kompilierung und reale Android-TV-Tests nicht seriös möglich. Fokusarbeiten sind code-seitig gebündelt; verbleibende Freigabeschritte: flutter analyze, flutter test, Android TV D-Pad/Back/OK/long-list manuell prüfen.

Mediatheken: kein Modul implementiert; wie vereinbart aus dem aktiven Umfang ausgeschlossen.

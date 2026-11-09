# Streamia Player – Recovery 43 Übergabe (09.11.2026)

## Ausgangsbasis
Recovery 42. Dieser Checkpoint enthält die vollständige Projektstruktur und alle bisherigen Recovery-Änderungen.

## Änderungen in Recovery 43

### Setup-Stabilität
- Netzwerk-IP-Ermittlung für den QR-/LAN-Import ist jetzt optional abgesichert. Wenn Android keine WLAN-IP liefern kann, bleibt der manuelle Playlist-Setup nutzbar.
- Der lokale Importserver wird mit Fehlerbehandlung gestartet. Ein Fehler beim Start des optionalen QR-/LAN-Servers blockiert den Setup-Assistenten nicht.
- QR-Link wird nur angezeigt, wenn der lokale Importserver tatsächlich eine Adresse zurückgegeben hat.
- Nach asynchroner WLAN-IP-Ermittlung wird geprüft, ob der Setup-Screen noch aktiv ist, bevor der Provider aus dem BuildContext gelesen wird.
- Playlist-Dateien werden als UTF-8 mit toleranter Behandlung ungültiger Bytes dekodiert. Das verhindert, dass Umlaute, kyrillische, polnische, spanische, französische oder arabische Titel durch eine einfache Byte-zu-Zeichen-Konvertierung beschädigt werden.

### Netzwerk-Timeout
- Der separate Legacy-M3U-URL-Lader validiert HTTP(S)-URLs vor dem Request.
- Der Request hat nun ein 30-Sekunden-Timeout, damit eine hängende Verbindung nicht unbegrenzt auf die Antwort wartet.

## Geplante Sprach-Tastatur-Funktion (vom Nutzer ausdrücklich gewünscht)
Nach Abschluss der Bedienungs-/Fernbedienungsprüfung folgt ein eigener Implementierungsblock für alle acht App-Sprachen:
- Deutsch (`de`)
- Türkisch (`tr`)
- Englisch (`en`)
- Russisch (`ru`)
- Polnisch (`pl`)
- Spanisch (`es`)
- Französisch (`fr`)
- Arabisch (`ar`, RTL)

Ziel: Die bei der Ersteinrichtung gewählte App-Sprache soll bei Texteingaben automatisch berücksichtigt werden. Auf Smartphones soll die passende verfügbare Android-IME-Sprache bevorzugt unterstützt und ein klarer Wechsel ermöglicht werden. Da Flutter/Android-Apps die installierte Tastaturbelegung nicht auf jedem Gerät zuverlässig erzwingen können, darf die Implementierung keine nicht vorhandene IME-Sprache vortäuschen. Fallbacks müssen die Eingabe weiterhin ermöglichen. Für Android TV ist eine D-pad-taugliche Lösung gesondert zu prüfen (System-IME-Unterstützung bzw. integrierte Bildschirmtastatur mit Sprachumschaltung).

Vor Implementierung alle Textfelder inventarisieren und nach Eingabeart unterscheiden: URL/Server, Benutzername, Passwort, Suchtext, E-Mail und freie Texte. URL-/E-Mail-Felder benötigen weiterhin passende Tastaturtypen; die gewählte Sprache soll insbesondere für sprachabhängige Texteingaben und Beschriftungen gelten.

## Prüfgrenzen
- Kein Flutter-/Dart-SDK in der Arbeitsumgebung; `flutter analyze`, Tests und APK-Build konnten nicht ausgeführt werden.
- Kein Android-Smartphone-/Android-TV-Gerät für Laufzeittests verfügbar.
- Änderungen wurden statisch geprüft; Netzwerkserver und QR-Import müssen auf realen Geräten getestet werden.

# Streamia Player – Recovery 35

## Inhalt

Dieser Stand setzt Recovery 34 fort und verbessert die Bedienbarkeit per Android-TV-Fernbedienung bzw. Tastatur in weiteren Bereichen:

- Sprachauswahl: Sprachkacheln besitzen nun abgerundete Fokusflächen und einen sichtbaren Fokuszustand.
- Kindersperre: Ziffernblock, Löschen und Entsperren gesperrter Ordner zeigen einen Fokuszustand und bleiben per OK/Enter aktivierbar.
- Paywall-Vorschau: Laufzeit-, Gerätepaket- und Vorschau-Schaltfläche zeigen beim Navigieren einen sichtbaren Fokuszustand. Es wird weiterhin keine Zahlung ausgelöst.
- Favoriten-Schaltfläche: Ohne Anmeldung bzw. ohne konfigurierte Synchronisierung wird ein deaktivierter, beschrifteter IconButton statt eines nicht fokussierbaren Symbols angezeigt.

## Unverändert / Grenzen

- Keine Änderung an Authentifizierung, Entitlements, Gerätebegrenzung, Favoriten-Datenmodell, Wiedergabe oder Supabase-Schema.
- Die Paywall ist weiterhin nur eine Vorschau; Zahlungsabwicklung und serverseitige Zahlungsprüfung sind nicht implementiert.
- Kein Flutter-/Dart-SDK in der Arbeitsumgebung. `flutter analyze`, Tests, APK-Build und reale Android-TV-/Fernbedienungstests konnten nicht ausgeführt werden.
- Die Änderungen sind daher statisch geprüft, aber nicht als kompilierter Build oder auf Hardware bestätigt.

## Fortsetzung

Nächster sinnvoller Arbeitsschritt: Fokusverhalten der übrigen Verwaltungs- und Listenansichten prüfen (Favoriten, Suche, Fortsetzen, Admin-Geräte, Setup) und anschließend mit Flutter-SDK auf Android-Touchgerät sowie Android-TV-/D-pad-Gerät testen.

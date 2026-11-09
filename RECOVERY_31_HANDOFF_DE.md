# Streamia Player – Recovery 31 Übergabe (09.11.2026)

## Arbeitsgrundlage
Recovery 31 baut vollständig auf Recovery 30 auf.

## Änderungen
- Audio- und Untertitelauswahl in `lib/screens/player_screen.dart` nutzt die typisierten `media_kit`-APIs statt `dynamic`.
- Automatische Auswahl ist in beiden Dialogen explizit verfügbar. Untertitel lassen sich zusätzlich ausschalten.
- Platzhalter-Tracks `auto` und `no` werden nicht als normale Streamspuren doppelt gelistet.
- Die aktive Auswahl wird im Dialog sichtbar markiert.
- Titel-/Sprachmetadaten werden ohne Nullfehler formatiert.

## Verifikation und Grenzen
- Die verwendeten API-Namen und Typen wurden mit der offiziellen media_kit-Dokumentation abgeglichen.
- `pubspec.yaml` deklariert `media_kit: ^1.1.10`; kein `pubspec.lock` vorhanden, daher ist die konkret aufgelöste 1.x-Version nicht festgeschrieben.
- Flutter-/Dart-SDK nicht vorhanden: kein `flutter analyze`, kein Build, keine APK und kein Gerätetest. Audio-/Untertitelverhalten muss mit realen Streams auf Android/Android TV geprüft werden.
- Keine Supabase-Migrationen live ausgeführt.

## Nächster Schritt
Fokus-Rückkehr und D-pad-Navigation bei Dialogen/Untermenüs sowie Wiedergabesteuerung auf Android TV weiter prüfen.

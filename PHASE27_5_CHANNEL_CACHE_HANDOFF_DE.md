# Streamia Player – Phase 27.5 – Autorisierte Senderliste / TV-Last
Datum: 21.11.2026

## Änderungen
- `lib/screens/player_screen.dart`: Erlaubte Live-TV-Sender werden für Senderwechsel und geöffnete Navigation einmalig pro unveränderter Content-/Familienversion gefiltert.
- Änderungen an Familie oder Content verwerfen den Cache vor der Prüfung einer laufenden Wiedergabe. Zusätzlich prüfen Cache-Zugriffe Source-Key und Identität der Senderliste. Bei nicht bereiter Familie bleibt die Liste leer.
- Keine neuen Decoder, Timer, Netzwerkaufrufe oder Änderungen an Smartphone-Layouts.
- `tool/check_phase27_5_channel_cache.py`: 10 neue statische Quellcode-Vertragsprüfungen.

## Grenzen
- Nur statische Vertragsprüfungen, keine echte Laufzeit-/CPU-Messung, keine Flutter-Compilation, keine Android-TV-Tests. Auf Nokia/TCL weiter prüfen.
- Der Cache setzt voraus, dass ContentProvider/FamilySessionProvider Änderungen per notifyListeners melden, wie es die bestehenden Listener voraussetzen.
- GitHub wurde nicht verändert.

## Commit-Vorschlag
`perf(tv): cache authorized live channels across zapping and navigation`

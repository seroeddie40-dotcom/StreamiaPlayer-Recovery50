# Streamia Player – Recovery 21

## Grundlage
Vollständiger Projektstand auf Basis von Recovery 20.

## Änderungen
- Einheitliches Verlaufmodell für Live-TV, VOD und Serien in `lib/providers/content_provider.dart`.
- Rechte Player-Seitenleiste mit Tabs für Live, Filme und Serien; pro Kategorie höchstens zehn aktuelle Einträge.
- Halbtransparenter Blur-/Glass-Stil für rechte Verlaufleiste und linke Episodenliste.
- Verlaufseinträge können erneut geöffnet werden.

## Noch offen
- Verlauf dauerhaft speichern und nach App-Neustart laden.
- Serien aus dem letzten Wiedergabefortschritt öffnen; Dialog „Weiterschauen / von vorne / Staffel und Folge wählen“.
- Linke Ordner-/Unterordnernavigation für Live-TV, VOD und Serien.
- Untere kontextabhängige Mediensteuerung inkl. Audio, Untertitel, Bildformat, Sender-/Episodenwechsel.
- Android-TV-Hardwaretest und Flutter-Build.

## Prüfhinweis
Flutter/Dart SDK ist in dieser Arbeitsumgebung nicht verfügbar. Es wurde daher kein Flutter-Build und kein Dart-Analyzer-Lauf behauptet.

# Phase 27.5 – Media3-Ereignisgenerationen (21.11.2026)

## Änderungen
- Native `TvMedia3PlatformView.kt`: Streamgeneration wird bei `open`, `stop` und beim Hintergrundwechsel erhöht; Status-/Fehlerereignisse tragen eine Generation; `open` bestätigt die aktuelle Generation.
- Flutter `lib/services/tv_media3_controller.dart`: ignoriert Ereignisse während eines ausstehenden `open` und Ereignisse anderer Streamgenerationen. Lokale asynchrone Antworten werden ebenfalls auf Aktualität geprüft.
- Kein zusätzlicher Decoder, kein neuer Timer und keine Änderungen am Smartphone-Layout.

## Einschränkungen
- Während des Öffnens eintreffende Zustandsereignisse werden absichtlich verworfen. Nachfolgende Ereignisse werden verarbeitet.
- Die native PlatformView wird laut Controller-Kommentar nicht automatisch für jeden PlayerScreen verwendet. Der Schutz gilt für die native Media3-Route, nicht pauschal für alle Wiedergabewege.
- Statische Tests sind keine Flutter-Kompilierung oder Android-TV-Gerätetests.

# Phase 27.5 – Decoderfehler ohne nutzlose Neustarts

Stand: 22.11.2026. Basis: Decoderdiagnose-Checkpoint (324 Dateien).

## Änderung
- `lib/screens/player_screen.dart`: Die gemeinsame Fehlerbehandlung unterstützt `allowAutomaticRetry`, standardmäßig `true`.
- Native Media3-Fehler `ERROR_CODE_DECODING_FORMAT_UNSUPPORTED`, `ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED`, `ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED` und `ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED` stoppen automatische Wiederholungen mit derselben URL.
- Alle übrigen Fehler behalten die bisherigen maximal zwei automatischen Versuche. Manueller Retry bleibt möglich.
- Keine zusätzlichen Timer, Player, Decoder, Stream-URLs in Logs oder Änderungen an Kindersicherung und Mobile-Player.

## Tests / Einschränkungen
- Statische Quellcodeprüfungen: siehe `tool/check_phase27_5_decoder_error_policy.py` und bestehende Phase-27.5-Prüfungen.
- Kein Flutter-SDK und kein Android-Gerät im Arbeitscontainer; Kompilierung, Wiedergabe und Fehlercode-Verhalten auf Nokia/TCL sind **nicht** validiert.
- Diese Klassifizierung gilt nur für explizit genannte Fehlercodes; andere Decoder-Initialisierungsfehler bleiben zunächst wiederholbar.

GitHub-Commit: `Phase 27.5: Nicht behebbare Media3-Formatfehler ohne Auto-Retry behandeln`

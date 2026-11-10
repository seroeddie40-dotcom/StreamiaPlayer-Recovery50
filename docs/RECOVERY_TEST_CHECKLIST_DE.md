# Recovery 3 – Prüf- und Abnahmecheckliste

## Lokal geprüft
- [x] Alle acht Sprachdateien sind syntaktisch gültiges JSON.
- [x] `pubspec.yaml` ist syntaktisch gültiges YAML.
- [x] Android MethodChannel-Implementierung ist vorhanden.
- [x] Auth-/Geräte-/Admin-Dateien sind im Projekt enthalten.
- [x] ZIP-Archiv wird nach Erstellung mit `unzip -t` geprüft.

## Noch auf Entwickler-PC / Staging auszuführen
- [ ] `flutter pub get`
- [ ] `dart format lib`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --debug`
- [ ] Supabase-Staging: Migration 001 anwenden; Auth-Trigger bleibt aktiv.
- [ ] Registrierung mit E-Mail-Bestätigung und Login testen.
- [ ] Ein neues Android-Gerät erhält genau 7 Tage; wiederholte Anmeldung verlängert nicht.
- [ ] App-Neuinstallation mit gleicher Android-ID setzt Trial nicht zurück.
- [ ] Gleicher physischer Fingerprint in anderem Konto erhält keine zweite Trial.
- [ ] Blockiertes Gerät bleibt nach erneuter Registrierung blockiert.
- [ ] Aktives Kundenpaket erlaubt genau 1 / 3 / 5 Geräte.
- [ ] Trial eines zusätzlichen Geräts umgeht kein aktives Paketlimit.
- [ ] Admin-Konto hat `plan_id IS NULL`, `subscription_ends_at IS NULL`, `manual_override=true` und 10 Geräte.
- [ ] Andere Admin-Konten haben keinen 10-Geräte-Override.
- [ ] Admin kann Geräte sehen, sperren und freigeben; normaler Benutzer kann keine fremden Geräte sehen.
- [ ] Parallele Geräte-Registrierung am Limit testen.

## Wichtiger Hinweis
Die Live-Datenbank wurde nicht verändert. Die SQL-Migration ist eine geprüfte Arbeitsdatei, keine bestätigte Live-Ausführung. Vor Staging-Anwendung Schema/Constraints und Funktionssignaturen gegen die aktuelle Supabase-Datenbank abgleichen.

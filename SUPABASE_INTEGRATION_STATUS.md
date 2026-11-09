# Streamia Player – Supabase-Integration

Stand: 08.11.2026 – Recovery-Arbeitsstand

## Flutter-Client jetzt enthalten
- Supabase Auth: E-Mail/Passwort-Registrierung und Anmeldung.
- Anmeldung ist Voraussetzung, bevor Setup/Dashboard geöffnet wird.
- Android-Gerätekennung über `Settings.Secure.ANDROID_ID` via MethodChannel; Gerätename über Hersteller/Modell.
- Fingerprint wird im Client mit SHA-256 gehasht. Es wird kein Hardware-MAC verwendet.
- Zufällige, lokal persistierte Installations-ID als Fallback.
- Nach Anmeldung: `register_my_device_v2`, danach `get_my_device_access_status`.
- Setup/Dashboard wird erst nach serverseitig bestätigtem `has_access=true` freigegeben.
- Admin-Menü prüft `is_streamia_admin`; Geräteübersicht lädt über `admin_list_my_devices`; Statusänderung über bestehendes `admin_set_device_status`.

## Erforderliche Datenbankmigration
In dieser Reihenfolge auf einer STAGING-Datenbank ausführen und testen:
1. Nur wenn die Datenbank noch leer ist: `202611070001_streamia_initial_schema.sql`.
2. Bei der bereits vorhandenen Streamia-Live-Datenbank: NICHT das Initialschema erneut ausführen. Die Live-Datenbank besitzt das abweichende Schema aus den vom Betreiber exportierten Tabellen/Funktionen.
3. `202611080001_per_device_trial_and_access.sql` gegen das vorhandene Live-Schema prüfen und auf Staging anwenden.
4. `202611080002_admin_device_management.sql` ist ein bewusst leerer Sequenz-Platzhalter; Admin-RPC und Admin-Limit werden in Migration 001 angelegt.

Die Migration 001 ist NICHT live angewendet. Sie setzt voraus, dass die Live-Tabellen `devices`, `entitlements`, `plans`, `app_admins` und `admin_audit_logs` sowie die exportierten Funktionen vorhanden sind. Vor Anwendung muss insbesondere geprüft werden, dass `entitlements.user_id` eindeutig/Primary Key ist und die `devices`-Spalten den Exporten entsprechen.

## Zugriffsmodell
- Ein physischer Fingerprint erhält höchstens eine 7-Tage-Testphase über `device_trial_registry`, unabhängig vom Benutzerkonto.
- Bestehende Installationen werden beim ersten erfolgreichen v2-Aufruf migriert/backfilled.
- Ein aktives bezahltes Abo ersetzt die Testphase als Zugriffsgrund und begrenzt aktive Geräte anhand des Pakets: 1/3/5.
- Der bestätigte Admin erhält `plan_id = NULL`, einen unbefristeten `admin_grant` und eine separate Obergrenze von 10 Geräten.
- Andere Admins erhalten keine automatische 10-Geräte-Ausnahme.
- Admin-Sperren werden durch Registrierung nicht aufgehoben.
- Registrierung wird pro Benutzer und Fingerprint durch Advisory Locks serialisiert.

## Einschränkungen / noch zu testen
- `ANDROID_ID` ist eine stabile Android-App-Signatur-/Benutzer-/Gerätekennung, aber keine unfehlbare Hardware-ID. Factory Reset, Profilwechsel oder Signaturwechsel können sie ändern. Ein absolut manipulationssicherer physischer Gerätebeweis ist mit einer normalen Flutter-App nicht möglich.
- Bei E-Mail-Bestätigung muss der Benutzer erst den Link bestätigen und sich anschließend anmelden.
- Keine Zahlung aktiviert ein Abo; Payment-/Store-Billing-Verifikation ist noch nicht implementiert.
- Der Datenbankcode muss auf Staging mit realen Testkonten und parallelen Registrierungen geprüft werden.
- In dieser Arbeitsumgebung sind Flutter/Dart und PostgreSQL-Client nicht installiert; kein erfolgreicher `flutter analyze`, APK-Build oder SQL-Ausführung wird behauptet.

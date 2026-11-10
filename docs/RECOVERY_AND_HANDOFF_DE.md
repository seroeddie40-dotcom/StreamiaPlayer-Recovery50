# Streamia Player – Wiederherstellung und Übergabe

Stand: 08.11.2026  
Projekt: vollständige Flutter-Projektstruktur aus dem zuletzt verfügbaren Voice-Search-Stand, ergänzt um nachweisbare Recovery-Unterlagen.

## Was in diesem Paket enthalten ist

- Flutter-Projekt inklusive Android-Projektdateien, Assets, Tests und CI-Workflow.
- Acht Sprachdateien: Deutsch, Türkisch, Englisch, Russisch, Polnisch, Spanisch, Französisch und Arabisch.
- Voice-Search-Komponente mit Auswahl verfügbarer Geräte-Spracherkennungs-Locale.
- Dashboard, Live-TV, VOD, Serien, Player, Login-/Paywall-/Setup-/Einstellungsansichten.
- Vorhandenes Supabase-Initialschema und ältere manuelle SQL-Hilfsdatei.
- Neue, separat gehaltene Migration für Admin-Geräteübersicht und den bestätigten 10-Geräte-Test-Override des Eigentümerkontos.
- Technischer Audit, Recovery-Checkliste und diese Übergabe.

## Wichtige Abgrenzung – nichts als live aktiviert ausgeben

Die verfügbaren Projekt-ZIPs (`streamiaplayer_supabase_database_ready.zip` und `streamiaplayer_voice_search_8_languages.zip`) enthalten beide denselben lokalen Demo-`AuthProvider` mit generierter MAC-ähnlicher Kennung. Die neuere Voice-Search-ZIP enthält zusätzlich die Master-Suche und Voice-Search-Komponente. Das Recovery-Baseline-ZIP enthält diese Dateien ebenfalls sowie zusätzliche Recovery-Dokumentation. Die `_2.zip`-Dateien sind Duplikate.

Daher ist echte Supabase-Authentifizierung, stabile physische Geräteidentität, Per-Device-Trial und die frühere erweiterte Gerätezugriffs-Migration **nicht im wiederhergestellten Flutter-Quellstand nachweisbar**. Sie werden hier nicht als fertig behauptet.

Die Migration `202611080002_admin_device_management.sql` ist eine rekonstruierte, eigenständige Ergänzung auf Basis der vom Eigentümer exportierten Live-Schema-Informationen. Sie ist **nicht auf Supabase ausgeführt**. Sie richtet den 10-Geräte-Override nur für `7947f863-ac28-41ef-a5c4-9154b6223f09` ein und stellt `admin_list_my_devices()` bereit. Sie implementiert NICHT allein die serverseitige Geräte-Cap-Durchsetzung. Die vorhandene `admin_set_device_status()`-RPC muss weiterhin genutzt werden, um Geräte freizugeben/zu sperren.

## Supabase-Schema und Sicherheitslage

Die gelieferten Exporte zeigen unter anderem `app_admins`, `devices`, `entitlements`, `plans`, `admin_audit_logs`, `profiles`, `user_settings`, `favorites`, `watch_history` und sieben bestehende Funktionen. Die bestehende `admin_grant_access()` akzeptiert `p_days = NULL` als unbefristeten Admin-Grant und setzt kein Kunden-`plan_id`. Das Admin-Konto soll keinen Kundenplan erhalten.

Vor Ausführung der neuen Migration müssen Tabellen-/Spaltennamen und Rechte nochmals im Zielprojekt geprüft werden. Die vorhandenen Auth-Trigger müssen erhalten bleiben. Niemals `service_role`-Key oder Datenbankpasswort in Flutter oder dieses ZIP legen.

## Prüfergebnisse dieses Wiederherstellungslaufs

- Alle sechs verfügbaren ZIP-Dateien mit `unzip -t` geprüft: keine Archivfehler.
- Die Sprachdateien werden im abschließenden Check auf gültiges JSON geprüft.
- Quellstände verglichen: Supabase-Ready und Voice-Search sind unterschiedliche Stände; die `_2`-Varianten sind Duplikate.
- Flutter/Dart SDK und PostgreSQL-Client sind in der Arbeitsumgebung nicht verfügbar. Deshalb wurden `flutter pub get`, `flutter analyze`, `flutter test`, Android-Build und SQL-Laufzeittests NICHT ausgeführt.
- Kein Datenbankzugriff auf das Live-Projekt wurde vorgenommen. Keine Migration wurde live angewendet.

## Nächster technischer Arbeitsblock

1. AuthProvider vollständig auf Supabase Auth umstellen und Login-/Registrierungs-UI verbinden.
2. Native Android-Gerätekennung plus sichere Installations-ID implementieren und gegen Reinstall-/Reset-Szenarien testen.
3. Per-Device-7-Tage-Trial mit serverseitigem Fingerprint-Registry, Replay-Schutz und atomarer Geräte-Cap-Durchsetzung konsolidieren.
4. Admin-Geräteansicht in Flutter an `admin_list_my_devices()` und `admin_set_device_status()` anbinden.
5. Admin-Dauerfreischaltung und 10-Geräte-Ausnahme ausschließlich für das bestätigte Eigentümerkonto im Backend setzen und verifizieren.
6. Danach Flutter-Analyse, Tests, Android-Build und reale TV-/Smartphone-Tests durchführen.

## Datenschutz / Produktgrenze

Streamia Player ist ein Player und stellt selbst keine Sender, Streams, Filme, Serien, Zugangsdaten oder Abonnements bereit. Nutzer fügen nur Quellen hinzu, zu deren Nutzung sie berechtigt sind.

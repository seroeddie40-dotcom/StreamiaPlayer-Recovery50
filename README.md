# Wichtiger Statushinweis

Dieses Repository ist noch kein produktionsreifer Release. Siehe [TECHNICAL_AUDIT_DE.md](TECHNICAL_AUDIT_DE.md) für bestätigte Lücken, Sicherheitsrisiken und den Teststatus. Insbesondere sind Login, Supabase und Zahlungen noch nicht produktiv implementiert.

# Streamia Player
Premium IPTV Player für Android, Android TV und Tablets.

## Build

flutter pub get
flutter build apk --debug  # installierbare lokale Test-APK; Release-Signierung siehe RECOVERY_79_HANDOFF_DE.md


## GitHub Actions
Automatischer APK-Build bei jedem Push auf `main`.


## Supabase-Verbindung

Das Projekt initialisiert den Supabase-Flutter-Client in `lib/main.dart`. Die
Projekt-URL und der öffentliche Publishable Key liegen als Standardwerte in
`lib/config/supabase_config.dart`. Diese Schlüsselart darf in einer Client-App
verwendet werden; Datenzugriffe müssen zwingend durch passende RLS-Policies
geschützt werden. Niemals einen `sb_secret_`- oder `service_role`-Key in die App
kompilieren.

Die Werte können beim Build überschrieben werden:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://zhwjlppqdulqtqxaakwl.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=DEIN_PUBLISHABLE_KEY
```

**Wichtiger Status:** Die Verbindung initialisiert den Supabase-Client. Das
allein erstellt noch keine Tabellen, Auth-Flows, RLS-Policies oder produktive
Geräte-/Premium-Logik. Diese Backend-Module müssen separat eingerichtet und
getestet werden.

import 'package:flutter/material.dart';
import '../core/focus_navigation.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import 'parental_lock_screen.dart';
import 'admin_devices_screen.dart';
import 'legal_disclaimer_screen.dart';
import 'favorites_backup_screen.dart';
import 'favorites_library_screen.dart';
import 'playlist_management_screen.dart';
import '../core/localization/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('de', 'Deutsch'), ('tr', 'Türkçe'), ('en', 'English'),
    ('ru', 'Русский'), ('ar', 'العربية'), ('pl', 'Polski'),
    ('es', 'Español'), ('fr', 'Français'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = theme.themeMode == ThemeMode.dark;
    final isConfigured = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: FocusTraversalGroup(child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          ListTile(
            autofocus: true,
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            title: const Text('Dark / Light Mode'),
            trailing: Switch(value: isDark, onChanged: (_) => theme.toggleTheme()),
            onTap: () => theme.toggleTheme(),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Sprache', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._languages.map((lang) => ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            title: Text(lang.$2),
            trailing: locale.locale.languageCode == lang.$1
                ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => locale.setLocale(lang.$1),
          )),
          const Divider(),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Rechtliche Hinweise / Disclaimer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushWithFocusRestore(context,
              MaterialPageRoute(builder: (_) => const LegalDisclaimerScreen())),
          ),
          const Divider(),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            leading: const Icon(Icons.playlist_play),
            title: Text(l10n.t('playlist_management')),
            subtitle: Text(l10n.t('playlist_management_subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushWithFocusRestore(context,
              MaterialPageRoute(builder: (_) => const PlaylistManagementScreen())),
          ),
          const Divider(),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            leading: const Icon(Icons.favorite),
            title: const Text('Meine Favoriten'),
            subtitle: const Text('Sender, Filme und Serien anzeigen und verwalten'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushWithFocusRestore(context,
              MaterialPageRoute(builder: (_) => const FavoritesLibraryScreen())),
          ),
          const Divider(),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Favoriten sichern & übertragen'),
            subtitle: const Text('Sender, Filme und Serien mit deinem Konto synchronisieren'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushWithFocusRestore(context,
              MaterialPageRoute(builder: (_) => const FavoritesBackupScreen())),
          ),
          const Divider(),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            title: const Text('Kindersperre'),
            trailing: const Icon(Icons.lock_outline),
            onTap: () => pushWithFocusRestore(context,
                MaterialPageRoute(builder: (_) => const ParentalLockScreen())),
          ),
          if (isConfigured) FutureBuilder<dynamic>(
            future: Supabase.instance.client.rpc('is_streamia_admin'),
            builder: (context, snapshot) => snapshot.data == true
              ? ListTile(
                  focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Admin – Geräteverwaltung'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => const AdminDevicesScreen())),
                ) : const SizedBox.shrink(),
          ),
          ListTile(
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            title: const Text('Abmelden'),
            trailing: const Icon(Icons.logout),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Abmelden?'),
                  content: const Text('Möchtest du dich wirklich abmelden?'),
                  actions: [
                    TextButton(
                      autofocus: true,
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Abmelden'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
        ],
      )),
    );
  }
}

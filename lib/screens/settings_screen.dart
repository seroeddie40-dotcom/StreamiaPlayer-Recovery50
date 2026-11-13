
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';

import 'parental_lock_screen.dart';
import 'admin_devices_screen.dart';
import 'legal_disclaimer_screen.dart';
import 'favorites_backup_screen.dart';
import 'favorites_library_screen.dart';
import 'playlist_management_screen.dart';
import 'recording_storage_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('de', 'Deutsch'),
    ('tr', 'Türkçe'),
    ('en', 'English'),
    ('ru', 'Русский'),
    ('ar', 'العربية'),
    ('pl', 'Polski'),
    ('es', 'Español'),
    ('fr', 'Français'),
  ];

  String _label(
    BuildContext context,
    String de,
    String tr,
    String en,
    String ru,
    String ar,
    String pl,
    String es,
    String fr,
  ) {
    final language =
        Localizations.localeOf(context).languageCode;

    switch (language) {
      case 'de':
        return de;
      case 'tr':
        return tr;
      case 'ru':
        return ru;
      case 'ar':
        return ar;
      case 'pl':
        return pl;
      case 'es':
        return es;
      case 'fr':
        return fr;
      default:
        return en;
    }
  }

  void _open(BuildContext context, Widget screen) {
    pushWithFocusRestore(
      context,
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    final auth = context.watch<AuthProvider>();

    final isDark = theme.themeMode == ThemeMode.dark;

    final isConfigured =
        Supabase.instance.client.auth.currentUser != null;

    final focusColor = Theme.of(context)
        .colorScheme
        .primary
        .withOpacity(0.16);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _label(
            context,
            'Einstellungen',
            'Ayarlar',
            'Settings',
            'Настройки',
            'الإعدادات',
            'Ustawienia',
            'Configuración',
            'Paramètres',
          ),
        ),
      ),
      body: SafeArea(
        child: FocusTraversalGroup(
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              ListTile(
                autofocus: true,
                focusColor: focusColor,
                title: const Text('Dark / Light Mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => theme.toggleTheme(),
                ),
                onTap: () => theme.toggleTheme(),
              ),

              const Divider(),

              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _label(
                    context,
                    'Sprache',
                    'Dil',
                    'Language',
                    'Язык',
                    'اللغة',
                    'Język',
                    'Idioma',
                    'Langue',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ..._languages.map(
                (lang) => ListTile(
                  focusColor: focusColor,
                  title: Text(lang.$2),
                  trailing:
                      locale.locale.languageCode == lang.$1
                          ? const Icon(
                              Icons.check,
                              color: Colors.green,
                            )
                          : null,
                  onTap: () => locale.setLocale(lang.$1),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                leading: const Icon(Icons.gavel_outlined),
                title: const Text(
                  'Rechtliche Hinweise / Disclaimer',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  const LegalDisclaimerScreen(),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                leading: const Icon(Icons.playlist_play),
                title: Text(
                  l10n.t('playlist_management'),
                ),
                subtitle: Text(
                  l10n.t('playlist_management_subtitle'),
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  const PlaylistManagementScreen(),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                leading: const Icon(
                  Icons.video_settings_outlined,
                ),
                title: Text(
                  _label(
                    context,
                    'Aufnahmespeicher',
                    'Kayıt depolama alanı',
                    'Recording storage',
                    'Хранилище записей',
                    'تخزين التسجيلات',
                    'Pamięć nagrań',
                    'Almacenamiento de grabaciones',
                    'Stockage des enregistrements',
                  ),
                ),
                subtitle: Text(
                  _label(
                    context,
                    'Aufnahmeordner auf Handy, USB-Stick oder Festplatte auswählen',
                    'Telefonda, USB bellekte veya diskte kayıt klasörü seç',
                    'Choose a recording folder on your device or USB drive',
                    'Выбрать папку для записей на устройстве или USB',
                    'اختيار مجلد التسجيل على الجهاز أو USB',
                    'Wybierz folder nagrań na urządzeniu lub USB',
                    'Elegir carpeta de grabaciones en el dispositivo o USB',
                    'Choisir un dossier sur l’appareil ou une clé USB',
                  ),
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  const RecordingStorageScreen(),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                leading: const Icon(Icons.favorite),
                title: const Text('Meine Favoriten'),
                subtitle: const Text(
                  'Sender, Filme und Serien anzeigen und verwalten',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  const FavoritesLibraryScreen(),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                leading:
                    const Icon(Icons.favorite_outline),
                title: const Text(
                  'Favoriten sichern & übertragen',
                ),
                subtitle: const Text(
                  'Sender, Filme und Serien mit deinem Konto synchronisieren',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  const FavoritesBackupScreen(),
                ),
              ),

              const Divider(),

              ListTile(
                focusColor: focusColor,
                title: const Text('Kindersperre'),
                trailing:
                    const Icon(Icons.lock_outline),
                onTap: () => _open(
                  context,
                  const ParentalLockScreen(),
                ),
              ),

              if (isConfigured)
                FutureBuilder<dynamic>(
                  future: Supabase.instance.client.rpc(
                    'is_streamia_admin',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      focusColor: focusColor,
                      leading: const Icon(
                        Icons.admin_panel_settings,
                      ),
                      title: const Text(
                        'Admin – Geräteverwaltung',
                      ),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        context,
                        const AdminDevicesScreen(),
                      ),
                    );
                  },
                ),

              ListTile(
                focusColor: focusColor,
                title: const Text('Abmelden'),
                trailing: const Icon(Icons.logout),
                onTap: () async {
                  final confirmed =
                      await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) =>
                        AlertDialog(
                      title:
                          const Text('Abmelden?'),
                      content: const Text(
                        'Möchtest du dich wirklich abmelden?',
                      ),
                      actions: [
                        TextButton(
                          autofocus: true,
                          onPressed: () =>
                              Navigator.pop(
                            dialogContext,
                            false,
                          ),
                          child: const Text(
                            'Abbrechen',
                          ),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(
                            dialogContext,
                            true,
                          ),
                          child: const Text(
                            'Abmelden',
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await auth.logout();

                    if (context.mounted) {
                      Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

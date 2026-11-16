
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/focus_navigation.dart';
import '../core/platform/device_layout.dart';
import '../core/localization/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_session_provider.dart';

import 'family_profile_selection_screen.dart';
import 'family_profile_management_screen.dart';
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
    final childProfileActive = context.watch<FamilySessionProvider>().isChild;

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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: DeviceLayout.isTelevision ? 920 : 720,
            ),
            child: FocusTraversalGroup(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: DeviceLayout.isTelevision ? 40 : 20,
                  vertical: DeviceLayout.isTelevision ? 28 : 16,
                ),
                children: [
                  ListTile(
                    autofocus: DeviceLayout.isTelevision,
                    focusColor: focusColor,
                    title: Text(_label(
                      context,
                      'Dunkel-/Hellmodus',
                      'Koyu / Açık Tema',
                      'Dark / Light Mode',
                      'Тёмная / светлая тема',
                      'الوضع الداكن / الفاتح',
                      'Tryb ciemny / jasny',
                      'Modo oscuro / claro',
                      'Mode sombre / clair',
                    )),
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
                    title: Text(_label(
                      context,
                      'Rechtliche Hinweise / Disclaimer',
                      'Yasal Bilgilendirme / Sorumluluk Reddi',
                      'Legal notices / Disclaimer',
                      'Правовая информация / Отказ от ответственности',
                      'إشعارات قانونية / إخلاء المسؤولية',
                      'Informacje prawne / Zastrzeżenie',
                      'Avisos legales / Aviso de responsabilidad',
                      'Mentions légales / Avertissement',
                    )),
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
                    title: Text(_label(
                      context,
                      'Meine Favoriten',
                      'Favorilerim',
                      'My favorites',
                      'Моё избранное',
                      'مفضلتي',
                      'Moje ulubione',
                      'Mis favoritos',
                      'Mes favoris',
                    )),
                    subtitle: Text(_label(
                      context,
                      'Sender, Filme und Serien anzeigen und verwalten',
                      'Filmler ve Diziler görüntüle ve yönet',
                      'View and manage channels, movies and series',
                      'Просмотр и управление каналами, фильмами и сериалами',
                      'عرض القنوات والأفلام والمسلسلات وإدارتها',
                      'Wyświetlaj kanały, filmy i seriale oraz zarządzaj nimi',
                      'Ver y gestionar canales, películas y series',
                      'Afficher et gérer les chaînes, films et séries',
                    )),
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
                    title: Text(_label(
                      context,
                      'Favoriten sichern & übertragen',
                      'Favorileri yedekle ve aktar',
                      'Back up & transfer favorites',
                      'Резервное копирование и перенос избранного',
                      'نسخ المفضلة احتياطياً ونقلها',
                      'Kopia zapasowa i przenoszenie ulubionych',
                      'Guardar y transferir favoritos',
                      'Sauvegarder et transférer les favoris',
                    )),
                    subtitle: Text(_label(
                      context,
                      'Sender, Filme und Serien mit deinem Konto synchronisieren',
                      'Kanalları, filmleri ve dizileri hesabınla eşitle',
                      'Sync channels, movies and series with your account',
                      'Синхронизация каналов, фильмов и сериалов с аккаунтом',
                      'مزامنة القنوات والأفلام والمسلسلات مع حسابك',
                      'Synchronizuj kanały, filmy i seriale z kontem',
                      'Sincroniza canales, películas y series con tu cuenta',
                      'Synchroniser les chaînes, films et séries avec votre compte',
                    )),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: () => _open(
                      context,
                      const FavoritesBackupScreen(),
                    ),
                  ),

                  const Divider(),

                  if (!childProfileActive) ...[
                  ListTile(
                    focusColor: focusColor,
                    leading: const Icon(
                      Icons.family_restroom_outlined,
                    ),
                    title: const Text('Familienprofile'),
                    subtitle: const Text(
                      'Profile auswählen und Kinderschutz verwalten',
                    ),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: () => _open(
                      context,
                      const FamilyProfileSelectionScreen(),
                    ),
                  ),

                  ListTile(
                    focusColor: focusColor,
                    leading: const Icon(
                      Icons.manage_accounts_outlined,
                    ),
                    title: const Text(
                      'Familienprofile verwalten',
                    ),
                    subtitle: const Text(
                      'Eltern-PIN, Profile und Ordnersperren',
                    ),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: () => _open(
                      context,
                      const FamilyProfileManagementScreen(),
                    ),
                  ),

                  ],

                  const Divider(),

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
                          title: Text(_label(
                            context,
                            'Admin – Geräteverwaltung',
                            'Yönetici – Cihaz Yönetimi',
                            'Admin – Device management',
                            'Администратор — управление устройствами',
                            'المشرف – إدارة الأجهزة',
                            'Administrator – Zarządzanie urządzeniami',
                            'Administrador – Gestión de dispositivos',
                            'Admin – Gestion des appareils',
                          )),
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
                    title: Text(_label(
                      context,
                      'Abmelden',
                      'Çıkış yap',
                      'Log out',
                      'Выйти',
                      'تسجيل الخروج',
                      'Wyloguj się',
                      'Cerrar sesión',
                      'Se déconnecter',
                    )),
                    trailing: const Icon(Icons.logout),
                    onTap: () async {
                      final confirmed =
                          await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) =>
                            AlertDialog(
                          title: Text(_label(
                            context,
                            'Abmelden?',
                            'Çıkış yapılsın mı?',
                            'Log out?',
                            'Выйти из аккаунта?',
                            'هل تريد تسجيل الخروج؟',
                            'Wylogować się?',
                            '¿Cerrar sesión?',
                            'Se déconnecter ?',
                          )),
                          content: Text(_label(
                            context,
                            'Möchtest du dich wirklich abmelden?',
                            'Gerçekten çıkış yapmak istiyor musunuz?',
                            'Are you sure you want to log out?',
                            'Вы действительно хотите выйти?',
                            'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                            'Czy na pewno chcesz się wylogować?',
                            '¿Seguro que quieres cerrar sesión?',
                            'Voulez-vous vraiment vous déconnecter ?',
                          )),
                          actions: [
                            TextButton(
                              autofocus: true,
                              onPressed: () =>
                                  Navigator.pop(
                                dialogContext,
                                false,
                              ),
                              child: Text(_label(
                                context,
                                'Abbrechen',
                                'İptal',
                                'Cancel',
                                'Отмена',
                                'إلغاء',
                                'Anuluj',
                                'Cancelar',
                                'Annuler',
                              )),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(
                                dialogContext,
                                true,
                              ),
                              child: Text(_label(
                                context,
                                'Abmelden',
                                'Çıkış yap',
                                'Log out',
                                'Выйти',
                                'تسجيل الخروج',
                                'Wyloguj się',
                                'Cerrar sesión',
                                'Se déconnecter',
                              )),
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
        ),
      ),
    );
  }
}

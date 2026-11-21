import '../widgets/tv_catalog_focus.dart';
import '../widgets/profile_clock.dart';
import '../services/live_stream_format.dart';
import '../services/live_stream_format_preferences.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/focus_navigation.dart';
import '../core/platform/device_layout.dart';
import '../core/localization/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';

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

  Future<void> _chooseLiveStreamFormat(BuildContext context) async {
    final isTv = DeviceLayout.isTelevision;
    final current = await LiveStreamFormatPreferences.load(isTv: isTv);
    if (!context.mounted) return;
    final selected = await showDialog<LiveStreamFormat>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_label(context,
          'Live-TV-Stream-Format', 'Canlı TV yayın biçimi',
          'Live TV stream format', 'Формат потока Live TV',
          'صيغة بث التلفزيون المباشر', 'Format strumienia TV',
          'Formato de transmisión TV', 'Format du flux TV')),
        children: [
          for (final option in LiveStreamFormat.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option),
              child: Row(children: [
                Expanded(child: Text(_formatName(context, option))),
                if (current == option) const Icon(Icons.check),
              ]),
            ),
        ],
      ),
    );
    if (selected == null) return;
    final saved = await LiveStreamFormatPreferences.save(selected, isTv: isTv);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? _label(context,
              'Stream-Format gespeichert. Player-Anbindung folgt.',
              'Yayın biçimi kaydedildi. Oynatıcı bağlantısı henüz bekliyor.',
              'Stream format saved. Player integration pending.',
              'Формат сохранён. Подключение к плееру ожидается.',
              'تم حفظ الصيغة. ربط المشغل قيد الانتظار.',
              'Zapisano format. Integracja z odtwarzaczem oczekuje.',
              'Formato guardado. Falta integrarlo con el reproductor.',
              'Format enregistré. Intégration au lecteur à venir.')
          : _label(context,
              'Speichern fehlgeschlagen', 'Kaydedilemedi', 'Could not save',
              'Не удалось сохранить', 'تعذر الحفظ', 'Nie zapisano',
              'No se pudo guardar', 'Échec de l’enregistrement')),
    ));
  }

  String _formatName(BuildContext context, LiveStreamFormat format) {
    switch (format) {
      case LiveStreamFormat.automatic:
        return _label(context, 'Automatisch', 'Otomatik', 'Automatic',
            'Автоматически', 'تلقائي', 'Automatycznie', 'Automático', 'Automatique');
      case LiveStreamFormat.hls:
        return 'HLS (.m3u8)';
      case LiveStreamFormat.mpegTs:
        return 'MPEG-TS (.ts)';
    }
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
                  TvCatalogFocus(child: ListTile(
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
                    // The ListTile is the single D-pad target on Android TV.
                    // The switch remains tappable on phones but must not create
                    // a second remote-focus stop inside the same setting.
                    trailing: DeviceLayout.isTelevision
                        ? ExcludeFocus(
                            child: Switch(
                              value: isDark,
                              onChanged: (_) => theme.toggleTheme(),
                            ),
                          )
                        : Switch(
                            value: isDark,
                            onChanged: (_) => theme.toggleTheme(),
                          ),
                    onTap: () => theme.toggleTheme(),
                  )),

                  const Divider(),
                  TvCatalogFocus(child: ListTile(
                    focusColor: focusColor,
                    leading: const Icon(Icons.settings_input_component),
                    title: Text(_label(context,
                      'Live-TV-Stream-Format', 'Canlı TV yayın biçimi',
                      'Live TV stream format', 'Формат потока Live TV',
                      'صيغة بث التلفزيون المباشر', 'Format strumienia TV',
                      'Formato de transmisión TV', 'Format du flux TV')),
                    subtitle: FutureBuilder<LiveStreamFormat>(
                      future: LiveStreamFormatPreferences.load(
                          isTv: DeviceLayout.isTelevision),
                      builder: (context, snapshot) => Text(_formatName(
                        context, snapshot.data ?? LiveStreamFormat.automatic)),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseLiveStreamFormat(context),
                  )),
                  const Divider(),
                  const ProfileClock(settings: true),
                  const Divider(),

                  TvCatalogFocus(child: ListTile(
                    focusColor: focusColor,
                    leading: const Icon(Icons.language),
                    title: Text(_label(context, 'Sprache', 'Dil', 'Language',
                      'Язык', 'اللغة', 'Język', 'Idioma', 'Langue')),
                    subtitle: Text(_languages.firstWhere(
                      (lang) => lang.$1 == locale.locale.languageCode,
                      orElse: () => _languages.first).$2),
                    trailing: const Icon(Icons.expand_more),
                    onTap: () async {
                      final selected = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) => SimpleDialog(
                          children: [
                            for (final lang in _languages)
                              SimpleDialogOption(
                                onPressed: () => Navigator.of(dialogContext).pop(lang.$1),
                                child: Row(children: [
                                  Expanded(child: Text(lang.$2)),
                                  if (locale.locale.languageCode == lang.$1)
                                    const Icon(Icons.check),
                                ]),
                              ),
                          ],
                        ),
                      );
                      if (!context.mounted || selected == null) return;
                      locale.setLocale(selected);
                    },
                  )),

                  const Divider(),

                  TvCatalogFocus(child: ListTile(
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
                  )),

                  const Divider(),

                  TvCatalogFocus(child: ListTile(
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
                  )),

                  const Divider(),

                  TvCatalogFocus(child: ListTile(
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
                  )),

                  const Divider(),

                  TvCatalogFocus(child: ListTile(
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
                  )),

                  const Divider(),

                  TvCatalogFocus(child: ListTile(
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
                  )),

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

                        return TvCatalogFocus(child: ListTile(
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
                        ));
                      },
                    ),

                  TvCatalogFocus(child: ListTile(
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
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

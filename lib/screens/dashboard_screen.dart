import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/storage/prefs_service.dart';

import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/content_provider.dart';
import 'providers/auth_provider.dart';
import 'services/playlist_profile_store.dart';

import 'screens/login_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_disclaimer_screen.dart';

class StreamiaApp extends StatelessWidget {
  final PrefsService prefsService;

  const StreamiaApp({
    super.key,
    required this.prefsService,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final contentProvider = context.watch<ContentProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Streamia Player',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,

      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,

      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // IMPORTANT:
      // No custom MaterialApp.builder overlay.
      // Flutter Navigator and Overlay remain intact.

      home: StartupGate(
        prefsService: prefsService,
        localeProvider: localeProvider,
        destination: _resolveHome(
          localeProvider,
          contentProvider,
          authProvider,
        ),
      ),
    );
  }

  Widget _resolveHome(
    LocaleProvider locale,
    ContentProvider content,
    AuthProvider auth,
  ) {
    if (!locale.hasSelectedLanguage) {
      return const LanguageSelectionScreen();
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!auth.accessChecked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Technical errors must not redirect to payment.
    if (auth.error != null) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.error,
      );
    }

    if (auth.deviceBlocked) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.blocked,
      );
    }

    // Account entitlement takes precedence over a pending device.
    if (auth.requiresPayment) {
      return const PaywallScreen();
    }

    if (auth.devicePending || !auth.deviceApproved) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.pending,
      );
    }

    if (!auth.hasAccess) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.error,
      );
    }

    if (!content.isLoaded) {
      return const _LibraryStartupGate();
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return const DashboardScreen();
  }
}


/// Localized recovery-first startup. The saved catalog is never loaded
/// automatically, so a broken playlist cannot block access to setup.
class _LibraryStartupGate extends StatefulWidget {
  const _LibraryStartupGate();

  @override
  State<_LibraryStartupGate> createState() => _LibraryStartupGateState();
}

class _LibraryStartupGateState extends State<_LibraryStartupGate> {
  bool _loading = false;
  String? _error;

  static const Map<String, List<String>> _translations = {
    'de': ['Sicherer Start', 'Die gespeicherte Mediathek wird nicht automatisch geladen. So kannst du die Einrichtung öffnen, auch wenn die letzte Playlist beim Laden Probleme verursacht hat. Deine gespeicherten Daten werden nicht gelöscht.', 'Playlist einrichten', 'Gespeicherte Mediathek laden', 'Keine gespeicherte Playlist gefunden.', 'Keine gespeicherte Mediathek gefunden.', 'Wiederherstellung fehlgeschlagen'],
    'tr': ['Güvenli Başlangıç', 'Kayıtlı medya kitaplığı otomatik olarak yüklenmez. Böylece son oynatma listesi yüklenirken sorun yaşansa bile kurulumu açabilirsin. Kayıtlı verilerin silinmez.', 'Oynatma listesi ekle', 'Kayıtlı medya kitaplığını yükle', 'Kayıtlı oynatma listesi bulunamadı.', 'Kayıtlı medya kitaplığı bulunamadı.', 'Geri yükleme başarısız'],
    'en': ['Safe Start', 'The saved media library is not loaded automatically. You can open setup even if the last playlist caused loading problems. Your saved data will not be deleted.', 'Set up playlist', 'Load saved media library', 'No saved playlist found.', 'No saved media library found.', 'Restore failed'],
    'ru': ['Безопасный запуск', 'Сохранённая медиатека не загружается автоматически. Вы можете открыть настройки, даже если последняя загрузка плейлиста вызвала ошибку. Ваши данные не будут удалены.', 'Настроить плейлист', 'Загрузить сохранённую медиатеку', 'Сохранённый плейлист не найден.', 'Сохранённая медиатека не найдена.', 'Ошибка восстановления'],
    'pl': ['Bezpieczny start', 'Zapisana biblioteka multimediów nie jest ładowana automatycznie. Możesz otworzyć konfigurację, nawet jeśli ostatnia lista odtwarzania powodowała problemy. Twoje dane nie zostaną usunięte.', 'Skonfiguruj playlistę', 'Wczytaj zapisaną bibliotekę', 'Nie znaleziono zapisanej playlisty.', 'Nie znaleziono zapisanej biblioteki.', 'Przywracanie nie powiodło się'],
    'es': ['Inicio seguro', 'La biblioteca guardada no se carga automáticamente. Puedes abrir la configuración aunque la última lista haya causado problemas. Tus datos guardados no se eliminarán.', 'Configurar lista', 'Cargar biblioteca guardada', 'No se encontró ninguna lista guardada.', 'No se encontró ninguna biblioteca guardada.', 'Error al restaurar'],
    'fr': ['Démarrage sécurisé', 'La médiathèque enregistrée ne se charge pas automatiquement. Vous pouvez accéder à la configuration même si la dernière playlist a posé problème. Vos données ne seront pas supprimées.', 'Configurer une playlist', 'Charger la médiathèque', 'Aucune playlist enregistrée.', 'Aucune médiathèque enregistrée.', 'Échec de la restauration'],
    'ar': ['بدء آمن', 'لن يتم تحميل مكتبة الوسائط المحفوظة تلقائيًا. يمكنك فتح الإعداد حتى إذا تسببت قائمة التشغيل الأخيرة في مشكلة أثناء التحميل. لن تُحذف بياناتك المحفوظة.', 'إعداد قائمة التشغيل', 'تحميل مكتبة الوسائط المحفوظة', 'لم يتم العثور على قائمة تشغيل محفوظة.', 'لم يتم العثور على مكتبة وسائط محفوظة.', 'فشلت الاستعادة'],
  };

  String _t(BuildContext context, int index) {
    final code = Localizations.localeOf(context).languageCode;
    return (_translations[code] ?? _translations['en']!)[index];
  }

  Future<void> _restoreOnDemand() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profiles = await PlaylistProfileStore().load();
      if (!mounted) return;
      if (profiles.isEmpty) {
        setState(() => _error = _t(context, 4));
        return;
      }
      final active = profiles.where((p) => p.isActive).firstOrNull ?? profiles.first;
      final restored = await context.read<ContentProvider>()
          .restoreStoredLibrary(active.sourceKey);
      if (!mounted) return;
      if (!restored) setState(() => _error = _t(context, 5));
    } catch (error) {
      if (mounted) setState(() => _error = '${_t(context, 6)}: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<ContentProvider>().isLoaded) {
      return const DashboardScreen();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Streamia Player')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(_t(context, 0),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_t(context, 1), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ),
                    icon: const Icon(Icons.playlist_add),
                    label: Text(_t(context, 2)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _restoreOnDemand,
                    icon: const Icon(Icons.restore),
                    label: Text(_t(context, 3)),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccessStatusMode {
  pending,
  blocked,
  error,
}

class _AccessStatusScreen extends StatefulWidget {
  final _AccessStatusMode mode;

  const _AccessStatusScreen({
    required this.mode,
  });

  @override
  State<_AccessStatusScreen> createState() => _AccessStatusScreenState();
}

class _AccessStatusScreenState extends State<_AccessStatusScreen> {
  String? _selectedDeviceId;

  Future<void> _showReplacementPreview(Map<String, dynamic> device) async {
    final language = context.read<LocaleProvider>().locale.languageCode;
    final name = (device['device_name']?.toString().trim().isNotEmpty ?? false)
        ? device['device_name'].toString()
        : (language == 'tr' ? 'İsimsiz cihaz'
            : language == 'de' ? 'Unbenanntes Gerät' : 'Unnamed device');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(language == 'tr' ? 'Cihazı değiştirmeyi onayla'
            : language == 'de' ? 'Gerätewechsel bestätigen'
            : 'Confirm device replacement'),
        content: Text(language == 'tr'
            ? '$name cihazının erişimi kaldırılacak ve mevcut kurulum etkinleştirilecek. '
              'Güvenlik denetimi henüz tamamlanmadığı için işlem şu anda devre dışıdır.'
            : language == 'de'
                ? 'Die bisherige Installation „$name“ würde deaktiviert und die aktuelle '
                  'Installation aktiviert. Der Wechsel ist noch gesperrt, bis die '
                  'serverseitige Sicherheitsprüfung abgeschlossen ist.'
                : 'The previous installation “$name” would be deactivated and the '
                  'current installation activated. Replacement is unavailable until '
                  'server-side security verification is complete.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(language == 'tr' ? 'İptal' : language == 'de' ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            onPressed: null,
            child: Text(language == 'tr' ? 'Cihazı değiştir'
                : language == 'de' ? 'Gerät ersetzen' : 'Replace device'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == _AccessStatusMode.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AuthProvider>().loadActiveDevices();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final language = context
        .watch<LocaleProvider>()
        .locale
        .languageCode;

    final isTurkish = language == 'tr';
    final isGerman = language == 'de';

    String title;
    String description;
    IconData symbol;

    switch (widget.mode) {
      case _AccessStatusMode.pending:
        title = isTurkish
            ? 'Cihaz onayı bekleniyor'
            : isGerman
                ? 'Gerätefreigabe ausstehend'
                : 'Device approval pending';

        description = isTurkish
            ? 'Bu cihaz kaydedildi ancak henüz '
              'onaylanmadı. Onaydan sonra tekrar '
              'kontrol edin.'
            : isGerman
                ? 'Dieses Gerät wurde registriert, '
                  'ist aber noch nicht freigegeben. '
                  'Nach der Freigabe kannst du den '
                  'Status erneut prüfen.'
                : 'This device is registered but '
                  'not yet approved. Check again '
                  'after approval.';

        symbol = Icons.hourglass_top_rounded;
        break;

      case _AccessStatusMode.blocked:
        title = isTurkish
            ? 'Cihaz erişimi engellendi'
            : isGerman
                ? 'Gerät nicht freigegeben'
                : 'Device access blocked';

        description = isTurkish
            ? 'Bu cihaz engellendi veya reddedildi.'
            : isGerman
                ? 'Dieses Gerät wurde gesperrt '
                  'oder abgelehnt.'
                : 'This device has been blocked '
                  'or rejected.';

        symbol = Icons.block_rounded;
        break;

      case _AccessStatusMode.error:
        title = isTurkish
            ? 'Erişim kontrolü başarısız'
            : isGerman
                ? 'Zugangsprüfung fehlgeschlagen'
                : 'Access verification failed';

        description = auth.error ??
            (isTurkish
                ? 'Lütfen tekrar deneyin.'
                : isGerman
                    ? 'Bitte versuche es erneut.'
                    : 'Please try again.');

        symbol = Icons.error_outline_rounded;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streamia Player'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    symbol,
                    size: 56,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  SelectableText(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                  ),

                  if (auth.deviceId != null) ...[
                    const SizedBox(height: 20),

                    const Text(
                      'Device ID',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    SelectableText(
                      auth.deviceId!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],

                  if (widget.mode == _AccessStatusMode.pending &&
                      auth.hasAccountAccess) ...[
                    const SizedBox(height: 24),
                    Text(
                      isTurkish ? 'Kayıtlı cihazlarınız'
                          : isGerman ? 'Deine aktiven Geräte'
                          : 'Your active devices',
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (auth.loadingDevices)
                      const CircularProgressIndicator()
                    else if (auth.deviceListError != null)
                      SelectableText(auth.deviceListError!,
                        textAlign: TextAlign.center)
                    else if (auth.activeDevices.isEmpty)
                      Text(isTurkish ? 'Aktif cihaz bulunamadı.'
                          : isGerman ? 'Keine aktiven Geräte gefunden.'
                          : 'No active devices found.')
                    else
                      ...auth.activeDevices.map((device) {
                        final id = device['device_id']?.toString() ?? '';
                        final name = (device['device_name']?.toString().trim().isNotEmpty ?? false)
                            ? device['device_name'].toString()
                            : (isTurkish ? 'İsimsiz cihaz'
                                : isGerman ? 'Unbenanntes Gerät' : 'Unnamed device');
                        return Card(
                          child: RadioListTile<String>(
                            value: id,
                            groupValue: _selectedDeviceId,
                            onChanged: (value) => setState(() => _selectedDeviceId = value),
                            title: Text(name),
                            subtitle: Text(device['platform']?.toString() ?? ''),
                            secondary: const Icon(Icons.devices),
                          ),
                        );
                      }),
                    if (auth.activeDevices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _selectedDeviceId == null ? null : () {
                            final matches = auth.activeDevices.where(
                              (device) => device['device_id']?.toString() == _selectedDeviceId,
                            );
                            if (matches.isNotEmpty) _showReplacementPreview(matches.first);
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(isTurkish ? 'Seçilen cihazı değiştir (önizleme)'
                              : isGerman ? 'Ausgewähltes Gerät ersetzen (Vorschau)'
                              : 'Replace selected device (preview)'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      isTurkish
                          ? 'Cihaz değiştirme, güvenlik kontrolü tamamlanınca açılacak.'
                          : isGerman
                              ? 'Der Gerätewechsel wird nach Abschluss der Sicherheitsprüfung freigeschaltet.'
                              : 'Device replacement will be enabled after security verification.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.loadingDevices ? null
                          : () => auth.loadActiveDevices(),
                      icon: const Icon(Icons.devices),
                      label: Text(isTurkish ? 'Listeyi yenile'
                          : isGerman ? 'Geräteliste aktualisieren'
                          : 'Refresh device list'),
                    ),
                  ],

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: auth.isBusy
                          ? null
                          : () {
                              auth.refreshDeviceAndAccess();
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        isTurkish
                            ? 'Tekrar kontrol et'
                            : isGerman
                                ? 'Erneut prüfen'
                                : 'Check again',
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            auth.logout();
                          },
                    child: Text(
                      isTurkish
                          ? 'Çıkış yap'
                          : isGerman
                              ? 'Abmelden'
                              : 'Log out',
                    ),
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

class StartupGate extends StatefulWidget {
  final PrefsService prefsService;
  final LocaleProvider localeProvider;
  final Widget destination;

  const StartupGate({
    super.key,
    required this.prefsService,
    required this.localeProvider,
    required this.destination,
  });

  @override
  State<StartupGate> createState() {
    return _StartupGateState();
  }
}

class _StartupGateState extends State<StartupGate> {
  bool _splashFinished = false;
  bool _legalDialogOpen = false;

  @override
  void initState() {
    super.initState();

    Timer(
      const Duration(milliseconds: 1700),
      () {
        if (!mounted) return;

        setState(() {
          _splashFinished = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashFinished) {
      return const SplashScreen();
    }

    if (!widget.localeProvider.hasSelectedLanguage) {
      return widget.destination;
    }

    if (!widget.prefsService
        .hasAcceptedCurrentLegalDisclaimer) {
      if (!_legalDialogOpen) {
        _legalDialogOpen = true;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
            if (!mounted) return;

            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => LegalDisclaimerScreen(
                  prefs: widget.prefsService,
                  requireAcceptance: true,
                  languageCode: widget
                      .localeProvider
                      .locale
                      .languageCode,
                ),
              ),
            );

            if (mounted) {
              setState(() {
                _legalDialogOpen = false;
              });
            }
          },
        );
      }

      return const SplashScreen();
    }

    return widget.destination;
  }
}

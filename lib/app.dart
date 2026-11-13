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
import 'services/playlist_switch_service.dart';

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


/// Automatically routes returning users to their library or playlist setup.
/// A temporary source failure never deletes stored playlist profiles.
class _LibraryStartupGate extends StatefulWidget {
  const _LibraryStartupGate();

  @override
  State<_LibraryStartupGate> createState() => _LibraryStartupGateState();
}

class _LibraryStartupGateState extends State<_LibraryStartupGate> {
  bool _loading = true;
  bool _hasProfiles = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    if (!mounted) return;
    setState(() { _loading = true; });
    try {
      final profiles = await PlaylistProfileStore().load();
      if (!mounted) return;
      if (profiles.isEmpty) {
        setState(() { _hasProfiles = false; _loading = false; });
        return;
      }
      _hasProfiles = true;
      final active = profiles.where((p) => p.isActive).firstOrNull ?? profiles.first;
      final content = context.read<ContentProvider>();
      // Prefer the encrypted offline catalog, so opening the app does not
      // depend on the playlist server being reachable.
      final restored = await content.restoreStoredLibrary(
        active.sourceKey, sourceLabel: active.displayName,
      );
      if (!restored && !content.isLoaded) {
        // No cached catalog: use the already saved secure source credentials.
        await PlaylistSwitchService().activate(active, content);
      }
      if (!mounted) return;
      if (!content.isLoaded) {
        setState(() { _loading = false; });
      }
    } catch (error) {
      debugPrint('Streamia startup library load failed: ${error.runtimeType}');
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _copy(BuildContext context, String de, String tr, String en) {
    final language = Localizations.localeOf(context).languageCode;
    return language == 'de' ? de : language == 'tr' ? tr : en;
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<ContentProvider>().isLoaded) {
      return const DashboardScreen();
    }
    if (!_loading && !_hasProfiles) {
      return const SetupScreen();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Streamia Player')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(_copy(context, 'Mediathek wird geladen…',
                      'Medya kitaplığı yükleniyor…', 'Loading your library…')),
                ] else ...[
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(_copy(context,
                    'Die gespeicherte Playlist konnte gerade nicht geladen werden. Deine Daten bleiben erhalten.',
                    'Kayıtlı oynatma listesi şu anda yüklenemiyor. Verileriniz korunur.',
                    'Your saved playlist could not be loaded. Your data is safe.'),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadLibrary,
                    icon: const Icon(Icons.refresh),
                    label: Text(_copy(context, 'Erneut versuchen', 'Tekrar dene', 'Retry')),
                  ),
                ],
                if (_hasProfiles) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ),
                    icon: const Icon(Icons.playlist_add),
                    label: Text(_copy(context, 'Playlist bearbeiten',
                        'Oynatma listesini düzenle', 'Edit playlist')),
                  ),
                ],
              ],
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
  bool _replacing = false;
  String? _replacementError;

  String _replacementMessage(Object error, String language) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('once per 24 hours') ||
        raw.contains('device_replacement_cooldown')) {
      const messages = <String, String>{
        'de': 'Ein Gerätewechsel wurde innerhalb der letzten 24 Stunden durchgeführt. Bitte versuche es später erneut. Deine Testzeit bleibt unverändert.',
        'tr': 'Son 24 saat içinde bir cihaz değiştirildi. Lütfen daha sonra tekrar deneyin. Deneme süreniz değişmez.',
        'en': 'A device was replaced within the last 24 hours. Please try again later. Your trial period is unchanged.',
        'ru': 'За последние 24 часа устройство уже заменяли. Повторите попытку позже. Пробный период не изменится.',
        'pl': 'W ciągu ostatnich 24 godzin wymieniono już urządzenie. Spróbuj ponownie później. Okres próbny nie ulegnie zmianie.',
        'es': 'Ya se sustituyó un dispositivo en las últimas 24 horas. Inténtalo más tarde. Tu periodo de prueba no cambia.',
        'fr': 'Un appareil a déjà été remplacé au cours des dernières 24 heures. Réessayez plus tard. Votre période d’essai reste inchangée.',
        'ar': 'تم استبدال جهاز خلال آخر 24 ساعة. يُرجى المحاولة لاحقًا. لن تتغير فترة التجربة.',
      };
      return messages[language] ?? messages['en']!;
    }
    const messages = <String, String>{
      'de': 'Der Gerätewechsel konnte nicht abgeschlossen werden. Bitte aktualisiere die Geräteliste und versuche es erneut.',
      'tr': 'Cihaz değişimi tamamlanamadı. Lütfen cihaz listesini yenileyip tekrar deneyin.',
      'en': 'Device replacement could not be completed. Refresh the device list and try again.',
      'ru': 'Не удалось заменить устройство. Обновите список устройств и попробуйте снова.',
      'pl': 'Nie udało się wymienić urządzenia. Odśwież listę urządzeń i spróbuj ponownie.',
      'es': 'No se pudo sustituir el dispositivo. Actualiza la lista e inténtalo de nuevo.',
      'fr': 'Impossible de remplacer l’appareil. Actualisez la liste et réessayez.',
      'ar': 'تعذر استبدال الجهاز. حدّث قائمة الأجهزة وحاول مرة أخرى.',
    };
    return messages[language] ?? messages['en']!;
  }

  Future<void> _confirmReplacement(Map<String, dynamic> device) async {
    if (_replacing) return;
    final language = context.read<LocaleProvider>().locale.languageCode;
    final name = device['device_name']?.toString().trim().isNotEmpty == true
        ? device['device_name'].toString()
        : language == 'tr' ? 'Önceki cihaz' : language == 'de' ? 'Bisheriges Gerät' : 'Previous device';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(language == 'tr' ? 'Cihaz değişimini onayla'
            : language == 'de' ? 'Gerätewechsel bestätigen' : 'Confirm device replacement'),
        content: Text(language == 'tr'
            ? '“$name” cihazının erişimi kaldırılacak ve bu kurulum etkinleştirilecek. Deneme süreniz değişmez.'
            : language == 'de'
                ? 'Der Zugang von „$name“ wird deaktiviert und diese Installation aktiviert. Die Testzeit bleibt unverändert.'
                : 'Access for “$name” will be disabled and this installation activated. Your trial period stays unchanged.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(language == 'tr' ? 'İptal' : language == 'de' ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(language == 'tr' ? 'Cihazı değiştir'
                : language == 'de' ? 'Gerät ersetzen' : 'Replace device'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _replacing = true; _replacementError = null; });
    try {
      await context.read<AuthProvider>().replaceActiveDevice(device['device_id'].toString());
    } catch (e) {
      if (mounted) setState(() => _replacementError = _replacementMessage(e, context.read<LocaleProvider>().locale.languageCode));
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
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
            ? 'Cihaz değişimi gerekiyor'
            : isGerman
                ? 'Gerätewechsel erforderlich'
                : 'Device replacement required';

        description = isTurkish
            ? 'Bu hesapta cihaz sınırına ulaşıldı. Önceki cihazınızı seçerek bu kurulumu etkinleştirebilirsiniz.'
            : isGerman
                ? 'Alle Geräteplätze dieses Kontos sind belegt. Wähle dein bisheriges Gerät aus, um diese Installation zu aktivieren.'
                : 'All device slots for this account are occupied. Select your previous device to activate this installation.';

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
                      SelectableText(_replacementMessage(auth.deviceListError!, language),
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
                          onPressed: _selectedDeviceId == null || _replacing ? null : () {
                            final matches = auth.activeDevices.where(
                              (device) => device['device_id']?.toString() == _selectedDeviceId,
                            );
                            if (matches.isNotEmpty) _confirmReplacement(matches.first);
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(isTurkish ? 'Seçilen cihazı değiştir'
                              : isGerman ? 'Ausgewähltes Gerät ersetzen'
                              : 'Replace selected device'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_replacing) const CircularProgressIndicator(),
                    if (_replacementError != null)
                      SelectableText(_replacementError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    Text(
                      isTurkish
                          ? 'Mevcut cihazı seçip değiştirerek bu kurulumu etkinleştirebilirsiniz. Deneme süresi sıfırlanmaz.'
                          : isGerman
                              ? 'Wähle dein bisheriges Gerät und ersetze es durch diese Installation. Die Testzeit wird nicht zurückgesetzt.'
                              : 'Select your previous device to activate this installation. Your trial period will not reset.',
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

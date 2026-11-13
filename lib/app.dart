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


/// Recovery-first startup: never deserialize a potentially huge saved catalog
/// automatically. The user can enter setup without deleting saved data.
class _LibraryStartupGate extends StatefulWidget {
  const _LibraryStartupGate();

  @override
  State<_LibraryStartupGate> createState() => _LibraryStartupGateState();
}

class _LibraryStartupGateState extends State<_LibraryStartupGate> {
  bool _loading = false;
  String? _error;

  Future<void> _restoreOnDemand() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profiles = await PlaylistProfileStore().load();
      if (!mounted) return;
      if (profiles.isEmpty) {
        setState(() => _error = 'Keine gespeicherte Playlist gefunden.');
        return;
      }
      final active = profiles.where((p) => p.isActive).firstOrNull ?? profiles.first;
      final restored = await context.read<ContentProvider>()
          .restoreStoredLibrary(active.sourceKey);
      if (!mounted) return;
      if (!restored) {
        setState(() => _error = 'Keine gespeicherte Mediathek gefunden.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Wiederherstellung fehlgeschlagen: $error');
      }
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
                  const Text('Sicherer Start',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Die gespeicherte Mediathek wird nicht automatisch geladen. '
                    'So kannst du die Einrichtung öffnen, auch wenn die letzte '
                    'Playlist beim Laden Probleme verursacht hat. '
                    'Deine gespeicherten Daten werden nicht gelöscht.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Playlist einrichten'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _restoreOnDemand,
                    icon: const Icon(Icons.restore),
                    label: const Text('Gespeicherte Mediathek laden'),
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

  Future<void> _confirmReplacement(Map<String, dynamic> device) async {
    final language = context.read<LocaleProvider>().locale.languageCode;
    final name = (device['device_name']?.toString().trim().isNotEmpty ?? false)
        ? device['device_name'].toString()
        : (language == 'tr' ? 'İsimsiz cihaz'
            : language == 'de' ? 'Unbenanntes Gerät' : 'Unnamed device');
    final id = device['device_id']?.toString();
    if (id == null || id.isEmpty) return;
    bool submitting = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(language == 'tr' ? 'Cihazı değiştirmeyi onayla'
              : language == 'de' ? 'Gerätewechsel bestätigen'
              : 'Confirm device replacement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(language == 'tr'
                  ? '“$name” cihazının erişimi kaldırılacak ve bu kurulum etkinleştirilecek. '
                    '24 saat içinde yalnızca bir cihaz değişikliği yapabilirsiniz.'
                  : language == 'de'
                      ? 'Die bisherige Installation „$name“ wird deaktiviert und diese '
                        'Installation freigeschaltet. Ein weiterer Wechsel ist erst '
                        'nach 24 Stunden möglich.'
                      : 'The previous installation “$name” will be deactivated and '
                        'this installation activated. Only one replacement is '
                        'allowed every 24 hours.'),
              if (submitting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                SelectableText(dialogError!,
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(language == 'tr' ? 'İptal'
                  : language == 'de' ? 'Abbrechen' : 'Cancel'),
            ),
            FilledButton(
              onPressed: submitting ? null : () async {
                updateDialog(() {
                  submitting = true;
                  dialogError = null;
                });
                final auth = context.read<AuthProvider>();
                final success = await auth.replaceSelectedDevice(id);
                if (!dialogContext.mounted) return;
                if (success) {
                  Navigator.of(dialogContext).pop();
                } else {
                  updateDialog(() {
                    submitting = false;
                    dialogError = auth.replacementError ??
                        'Der Gerätewechsel konnte nicht abgeschlossen werden.';
                  });
                }
              },
              child: Text(language == 'tr' ? 'Cihazı değiştir'
                  : language == 'de' ? 'Gerät ersetzen' : 'Replace device'),
            ),
          ],
        ),
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
                    Text(
                      isTurkish
                          ? 'Cihaz değişimi hesap sahibi tarafından onaylanır. 24 saatlik sınır geçerlidir.'
                          : isGerman
                              ? 'Du entscheidest, welches Gerät ersetzt wird. Pro 24 Stunden ist ein Wechsel möglich.'
                              : 'Choose which device to replace. One replacement is allowed every 24 hours.',
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

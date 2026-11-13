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

class _AccessStatusScreen extends StatelessWidget {
  final _AccessStatusMode mode;

  const _AccessStatusScreen({required this.mode});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final language = context.watch<LocaleProvider>().locale.languageCode;
    final isGerman = language == 'de';
    final isTurkish = language == 'tr';

    final String title;
    final String description;
    final IconData icon;

    switch (mode) {
      case _AccessStatusMode.pending:
        title = isGerman
            ? 'Zugang noch nicht verfügbar'
            : isTurkish
                ? 'Erişim henüz kullanılamıyor'
                : 'Access not yet available';
        description = isGerman
            ? 'Für dieses Konto ist derzeit kein weiterer Geräteplatz frei. '
              'Du kannst die App auf deinem bereits freigeschalteten Gerät verwenden. '
              'Deine Testzeit bleibt unverändert.'
            : isTurkish
                ? 'Bu hesap için şu anda başka bir cihaz hakkı yok. '
                  'Uygulamayı daha önce etkinleştirilmiş cihazda kullanabilirsiniz. '
                  'Deneme süreniz değişmez.'
                : 'This account currently has no additional device slot. '
                  'Use the app on your already activated device. '
                  'Your trial period is unchanged.';
        icon = Icons.lock_outline;
        break;
      case _AccessStatusMode.blocked:
        title = isGerman
            ? 'Zugang nicht verfügbar'
            : isTurkish
                ? 'Erişim kullanılamıyor'
                : 'Access unavailable';
        description = isGerman
            ? 'Dieses Gerät ist für das Konto nicht freigeschaltet.'
            : isTurkish
                ? 'Bu cihaz hesap için etkinleştirilmemiş.'
                : 'This device is not authorized for the account.';
        icon = Icons.lock_outline;
        break;
      case _AccessStatusMode.error:
        title = isGerman
            ? 'Verbindung konnte nicht geprüft werden'
            : isTurkish
                ? 'Bağlantı doğrulanamadı'
                : 'Could not verify access';
        description = isGerman
            ? 'Die Zugangsprüfung ist fehlgeschlagen. Bitte prüfe deine '
              'Internetverbindung und versuche es erneut.'
            : isTurkish
                ? 'Erişim kontrolü başarısız oldu. İnternet bağlantınızı '
                  'kontrol edip yeniden deneyin.'
                : 'Access verification failed. Check your internet '
                  'connection and try again.';
        icon = Icons.wifi_off_outlined;
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Streamia Player')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Text(description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: auth.isBusy ? null : () => auth.refreshDeviceAndAccess(),
                      icon: const Icon(Icons.refresh),
                      label: Text(isGerman ? 'Erneut prüfen'
                          : isTurkish ? 'Yeniden kontrol et' : 'Try again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isBusy ? null : () => auth.logout(),
                    child: Text(isGerman ? 'Abmelden'
                        : isTurkish ? 'Çıkış yap' : 'Log out'),
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

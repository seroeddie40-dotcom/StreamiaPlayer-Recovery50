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

    // Do not flash the login screen while restoring a persisted session.
    if (auth.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      return const _DeviceActivationGate();
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
  blocked,
  error,
}

/// Only shown when the server has no free slot for this installation.
/// No standalone device-replacement page: a one-time, explicit-choice dialog
/// sits over the startup loading surface. The dashboard remains access-gated.
class _DeviceActivationGate extends StatefulWidget {
  const _DeviceActivationGate();

  @override
  State<_DeviceActivationGate> createState() => _DeviceActivationGateState();
}

class _DeviceActivationGateState extends State<_DeviceActivationGate> {
  String? _selected;
  String? _error;
  bool _working = false;
  bool _dialogOpen = false;

  String _tr(String de, String tr, String en) {
    final language = context.read<LocaleProvider>().locale.languageCode;
    return language == 'de' ? de : language == 'tr' ? tr : en;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    final auth = context.read<AuthProvider>();
    await auth.loadActiveDevices();
    if (!mounted || !auth.devicePending) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => Consumer<AuthProvider>(
          builder: (dialogContext, current, _) {
            final devices = current.activeDevices;
            return AlertDialog(
              title: Text(_tr('Geräteplatz belegt', 'Cihaz sınırına ulaşıldı', 'Device limit reached')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tr(
                        'Wähle ein bisheriges Gerät, das du durch dieses Gerät ersetzen möchtest.',
                        'Bu cihazla değiştirmek istediğiniz eski cihazı seçin.',
                        'Choose an existing device to replace with this one.',
                      )),
                      const SizedBox(height: 12),
                      if (current.loadingDevices) const Center(child: CircularProgressIndicator()),
                      if (!current.loadingDevices && devices.isEmpty)
                        Text(_tr('Keine ersetzbaren Geräte gefunden. Bitte erneut prüfen.',
                          'Değiştirilebilecek cihaz bulunamadı. Lütfen tekrar kontrol edin.',
                          'No replaceable devices found. Please check again.')),
                      for (final device in devices)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(device['device_name']?.toString() ?? _tr('Gerät', 'Cihaz', 'Device')),
                          subtitle: Text(device['platform']?.toString() ?? ''),
                          value: device['device_id'].toString(),
                          groupValue: _selected,
                          onChanged: _working ? null : (id) => updateDialog(() => _selected = id),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      if (_working) const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _working ? null : () async {
                    Navigator.of(dialogContext).pop();
                    await context.read<AuthProvider>().logout();
                  },
                  child: Text(_tr('Abmelden', 'Çıkış yap', 'Log out')),
                ),
                TextButton(
                  onPressed: _working ? null : () async {
                    updateDialog(() => _error = null);
                    await current.loadActiveDevices();
                  },
                  child: Text(_tr('Aktualisieren', 'Yenile', 'Refresh')),
                ),
                FilledButton(
                  onPressed: _working || _selected == null ? null : () async {
                    final id = _selected!;
                    final selectedDevice = devices.where((d) => d['device_id'].toString() == id);
                    if (selectedDevice.isEmpty) return;
                    final name = selectedDevice.first['device_name']?.toString() ?? id;
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmationContext) => AlertDialog(
                        title: Text(_tr('Gerät ersetzen?', 'Cihaz değiştirilsin mi?', 'Replace device?')),
                        content: Text(_tr(
                          '„$name“ wird abgemeldet. Die Testzeit bleibt unverändert.',
                          '“$name” cihazının erişimi kaldırılacak. Deneme süresi değişmez.',
                          '“$name” will lose access. Your trial period is unchanged.',
                        )),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(confirmationContext, false),
                            child: Text(_tr('Abbrechen', 'İptal', 'Cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(confirmationContext, true),
                            child: Text(_tr('Ersetzen', 'Değiştir', 'Replace'))),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    updateDialog(() { _working = true; _error = null; });
                    try {
                      await current.replaceActiveDevice(id);
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    } catch (_) {
                      if (dialogContext.mounted) updateDialog(() {
                        _error = _tr('Gerätewechsel nicht möglich. Bitte erneut versuchen.',
                          'Cihaz değiştirilemedi. Lütfen tekrar deneyin.',
                          'Device replacement failed. Please try again.');
                      });
                    } finally {
                      if (dialogContext.mounted) updateDialog(() => _working = false);
                    }
                  },
                  child: Text(_tr('Gerät ersetzen', 'Cihazı değiştir', 'Replace device')),
                ),
              ],
            );
          },
        ),
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Only hard blocks and access errors use a dedicated page.
/// A pending replacement is handled by _DeviceActivationGate as a dialog.
class _AccessStatusScreen extends StatelessWidget {
  final _AccessStatusMode mode;
  const _AccessStatusScreen({required this.mode});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String copy(String de, String tr, String en) =>
        lang == 'de' ? de : lang == 'tr' ? tr : en;
    final blocked = mode == _AccessStatusMode.blocked;
    return Scaffold(
      appBar: AppBar(title: const Text('Streamia Player')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(blocked ? Icons.block : Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(blocked
                    ? copy('Dieses Gerät wurde gesperrt.', 'Bu cihaz engellendi.',
                        'This device has been blocked.')
                    : copy('Die Zugangsprüfung ist fehlgeschlagen.',
                        'Erişim kontrolü başarısız.', 'Access verification failed.'),
                    textAlign: TextAlign.center),
                if (!blocked && auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(copy('Bitte versuche es erneut.', 'Lütfen tekrar deneyin.',
                      'Please try again.'), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.isBusy ? null : auth.refreshDeviceAndAccess,
                  child: Text(copy('Erneut prüfen', 'Tekrar kontrol et', 'Check again')),
                ),
                TextButton(
                  onPressed: auth.isBusy ? null : auth.logout,
                  child: Text(copy('Abmelden', 'Çıkış yap', 'Log out')),
                ),
              ],
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/platform/device_layout.dart';
import 'core/platform/tv_remote_navigation.dart';
import 'core/localization/app_localizations.dart';
import 'core/storage/prefs_service.dart';

import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/content_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/family_session_provider.dart';
import 'screens/family_profile_selection_screen.dart';
import 'services/playlist_profile_store.dart';
import 'models/playlist_profile.dart';
import 'services/family_profile_service.dart';
import 'services/playlist_switch_service.dart';

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/paywall_screen.dart';
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

      theme: TvRemoteNavigation.theme(AppTheme.light),
      darkTheme: TvRemoteNavigation.theme(AppTheme.dark),
      shortcuts: DeviceLayout.isTelevision
          ? TvRemoteNavigation.shortcuts
          : null,
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
      return _startupLoading(locale.locale.languageCode);
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!auth.accessChecked || (auth.isBusy && auth.error == null)) {
      return _startupLoading(locale.locale.languageCode);
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

    // The gate owns the completion of the startup transaction. Do not bypass
    // it merely because an asynchronous catalog publish notified listeners.
    return const _LibraryStartupGate();
  }
}


Widget _startupLoading(String language) => _StartupLoading(language: language);

class _StartupLoading extends StatefulWidget {
  final String language;
  const _StartupLoading({required this.language});

  @override
  State<_StartupLoading> createState() => _StartupLoadingState();
}

class _StartupLoadingState extends State<_StartupLoading> {
  Timer? _timer;
  bool _timedOut = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const messages = {
      'de': ['Konto und Gerätezugang werden geprüft…', 'Die Prüfung dauert zu lange. Bitte prüfe deine Internetverbindung.', 'Erneut prüfen', 'Abmelden'],
      'tr': ['Hesap ve cihaz erişimi kontrol ediliyor…', 'Kontrol çok uzun sürdü. İnternet bağlantınızı kontrol edin.', 'Tekrar kontrol et', 'Çıkış yap'],
      'en': ['Checking account and device access…', 'Verification is taking too long. Check your internet connection.', 'Check again', 'Log out'],
      'ru': ['Проверка аккаунта и доступа устройства…', 'Проверка занимает слишком много времени. Проверьте интернет.', 'Повторить', 'Выйти'],
      'pl': ['Sprawdzanie konta i dostępu urządzenia…', 'Weryfikacja trwa zbyt długo. Sprawdź połączenie internetowe.', 'Sprawdź ponownie', 'Wyloguj'],
      'es': ['Comprobando la cuenta y el acceso del dispositivo…', 'La comprobación tarda demasiado. Comprueba tu conexión.', 'Reintentar', 'Cerrar sesión'],
      'fr': ['Vérification du compte et de l’accès de l’appareil…', 'La vérification prend trop de temps. Vérifiez votre connexion.', 'Réessayer', 'Se déconnecter'],
      'ar': ['جارٍ التحقق من الحساب والوصول إلى الجهاز…', 'استغرق التحقق وقتًا طويلاً. تحقق من اتصال الإنترنت.', 'إعادة المحاولة', 'تسجيل الخروج'],
    };
    final labels = messages[widget.language] ?? messages['en']!;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_timedOut) const SplashScreen(),
          if (!_timedOut) const ColoredBox(color: Color(0x55000000)),
          Align(
            alignment: _timedOut ? Alignment.center : Alignment.bottomCenter,
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_timedOut) const Icon(Icons.error_outline, size: 44)
            else const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(labels[_timedOut ? 1 : 0], textAlign: TextAlign.center,
                style: _timedOut ? null : const TextStyle(color: Colors.white)),
            if (_timedOut) ...[
              const SizedBox(height: 20),
              FilledButton(
                autofocus: true,
                onPressed: _retrying ? null : () async {
                  setState(() { _timedOut = false; _retrying = true; });
                  _startTimer();
                  try {
                    await auth.refreshDeviceAndAccess();
                  } catch (_) {
                    if (mounted) setState(() => _timedOut = true);
                  } finally {
                    if (mounted) setState(() => _retrying = false);
                  }
                },
                child: Text(labels[2]),
              ),
              TextButton(onPressed: auth.isBusy ? null : auth.logout, child: Text(labels[3])),
            ],
          ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keep onboarding in portrait on phones while restoring the original
/// landscape experience as soon as the library/dashboard is displayed.
/// Android TV always remains in landscape.
class _LandscapeDashboard extends StatefulWidget {
  const _LandscapeDashboard();

  @override
  State<_LandscapeDashboard> createState() => _LandscapeDashboardState();
}

class _LandscapeDashboardState extends State<_LandscapeDashboard> {
  bool _checkingDefault = true;

  Future<void> _tryDefaultProfile() async {
    if (!mounted) return;
    final family = context.read<FamilySessionProvider>();
    final accountId = context.read<AuthProvider>().user?.id;
    try {
      if (accountId == null || family.isReady || family.isLoading) return;
      final profile = await FamilyProfileService().ensureDefaultProfile()
          .timeout(const Duration(seconds: 15));
      if (!mounted || context.read<AuthProvider>().user?.id != accountId ||
          family.isReady || family.isLoading) return;
      await family.activateProfile(profile);
    } catch (_) {
      // Protected accounts and unsuccessful checks must use profile selection.
    } finally {
      if (mounted) setState(() => _checkingDefault = false);
    }
  }
  @override
  void initState() {
    super.initState();
    _applyOrientation(landscape: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryDefaultProfile());
  }

  @override
  void dispose() {
    // A user who signs out returns to portrait onboarding on a phone.
    _applyOrientation(landscape: false);
    super.dispose();
  }

  void _applyOrientation({required bool landscape}) {
    if (DeviceLayout.isTelevision) return;
    final orientations = landscape
        ? <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : <DeviceOrientation>[DeviceOrientation.portraitUp];
    unawaited(SystemChrome.setPreferredOrientations(orientations));
  }

  @override
  Widget build(BuildContext context) {
    // Only a verified session may expose the dashboard. Try automatic
    // activation once per entry, not after an explicit profile switch.
    final family = context.watch<FamilySessionProvider>();
    if (_checkingDefault) {
      // Keep the branded startup screen visible while the server verifies
      // whether the default adult profile may be entered automatically.
      // Never show the dashboard before family authorization succeeds.
      return const SplashScreen();
    }
    if (!family.isReady) {
      return const FamilyProfileSelectionScreen();
    }
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
  bool _loadFailed = false;
  bool _startupReady = false;
  String _loadStage = 'profiles';
  int? _xtreamCompleted;
  int _progressPercent = 0;
  int _completedPhases = 0;
  (int, int, int)? _m3uCounts;
  int _loadAttempt = 0;
  Stopwatch? _loadWatch;
  // Dart Future.timeout does not cancel the underlying database/network work.
  // Keep the original operation until it really finishes so Retry cannot
  // start another restore or activation against the same catalog.
  Future<List<PlaylistProfile>>? _pendingProfiles;
  Future<bool>? _pendingRestore;
  Future<bool>? _pendingActivation;
  String? _pendingSourceKey;

  // A timed-out secure-storage read continues in the background. Reuse it
  // instead of issuing another read when the user taps Retry.
  Future<List<PlaylistProfile>> _loadProfilesOnce() {
    final existing = _pendingProfiles;
    if (existing != null) return existing;
    final task = PlaylistProfileStore().load();
    _pendingProfiles = task;
    unawaited(task.then((_) {
      if (identical(_pendingProfiles, task)) _pendingProfiles = null;
    }, onError: (Object _, StackTrace __) {
      if (identical(_pendingProfiles, task)) _pendingProfiles = null;
    }));
    return task;
  }

  Future<bool> _restoreOnce(ContentProvider content, String sourceKey,
      String sourceLabel) {
    if (_pendingSourceKey != sourceKey) {
      _pendingSourceKey = sourceKey;
      _pendingRestore = null;
      _pendingActivation = null;
    }
    final existing = _pendingRestore;
    if (existing != null) return existing;
    final task = content.restoreStoredLibrary(
      sourceKey, sourceLabel: sourceLabel,
    );
    _pendingRestore = task;
    unawaited(task.then((_) {
      if (identical(_pendingRestore, task)) _pendingRestore = null;
    }, onError: (Object _, StackTrace __) {
      if (identical(_pendingRestore, task)) _pendingRestore = null;
    }));
    return task;
  }

  Future<bool> _activateOnce(ContentProvider content, PlaylistProfile profile,
      int attempt) {
    final existing = _pendingActivation;
    if (existing != null) return existing;
    final task = PlaylistSwitchService().activate(
      profile, content,
      onM3uProgress: (live, movies, series) {
        if (mounted && attempt == _loadAttempt) {
          setState(() => _m3uCounts = (live, movies, series));
        }
      },
      onXtreamProgress: (completed, _) {
        if (mounted && attempt == _loadAttempt) {
          setState(() {
            _xtreamCompleted = completed;
            _completedPhases = completed;
            // Reserve 100% for the successfully published catalog.
            _progressPercent = completed == 3 ? 95 : 20 + (completed * 25);
          });
        }
      },
    );
    _pendingActivation = task;
    unawaited(task.then((_) {
      if (identical(_pendingActivation, task)) _pendingActivation = null;
    }, onError: (Object _, StackTrace __) {
      if (identical(_pendingActivation, task)) _pendingActivation = null;
    }));
    return task;
  }

  @override
  void initState() {
    super.initState();
    if (context.read<ContentProvider>().isLoaded) {
      _startupReady = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
    }
  }

  Future<void> _loadLibrary() async {
    if (!mounted || _loading && _loadAttempt > 0) return;
    final attempt = ++_loadAttempt;
    final watch = Stopwatch()..start();
    _loadWatch = watch;
    debugPrint('[Streamia/Library] attempt=$attempt started');
    setState(() { _loading = true; _loadFailed = false; _loadStage = 'profiles'; _xtreamCompleted = null; _m3uCounts = null; _progressPercent = 0; _completedPhases = 0; });
    final content = context.read<ContentProvider>();
    try {
      final profiles = await _loadProfilesOnce();
      debugPrint('[Streamia/Library] profiles ready after ${watch.elapsedMilliseconds}ms; count=${profiles.length}');
      if (!mounted || attempt != _loadAttempt) return;
      if (profiles.isEmpty) {
        setState(() { _hasProfiles = false; _loading = false; });
        return;
      }
      _hasProfiles = true;
      setState(() { _loadStage = 'local'; _progressPercent = 10; });
      final active = profiles.where((p) => p.isActive).firstOrNull ?? profiles.first;
      // A timed-out activation may still be running. Rejoin it instead of
      // beginning a new restore, which would invalidate its generation.
      if (_pendingSourceKey == active.sourceKey && _pendingActivation != null) {
        setState(() { _loadStage = 'network'; _progressPercent = 20; });
        final activated = await _pendingActivation!;
        if (!activated && !content.isLoaded) {
          throw StateError('Playlist activation did not complete');
        }
        if (!mounted || attempt != _loadAttempt) return;
        if (content.isLoaded) {
          setState(() { _progressPercent = 100; _completedPhases = 3; _startupReady = true; _loading = false; });
        } else {
          throw StateError('Playlist activation did not publish a library');
        }
        return;
      }
      // Prefer the encrypted offline catalog, so opening the app does not
      // depend on the playlist server being reachable.
      final restored = await _restoreOnce(
        content, active.sourceKey, active.displayName,
      );
      debugPrint('[Streamia/Library] local restore finished after ${watch.elapsedMilliseconds}ms; restored=$restored');
      if (!restored && !content.isLoaded) {
        // No cached catalog: use the already saved secure source credentials.
        if (!mounted || attempt != _loadAttempt) return;
        setState(() { _loadStage = 'network'; _progressPercent = 20; });
        final activated = await _activateOnce(
          content, active, attempt,
        );
        debugPrint('[Streamia/Library] network activation finished after ${watch.elapsedMilliseconds}ms; activated=$activated');
        if (!activated && !content.isLoaded) {
          throw StateError('Playlist activation did not complete');
        }
      }
      if (!mounted || attempt != _loadAttempt) return;
      if (content.isLoaded) {
        setState(() { _progressPercent = 100; _completedPhases = 3; _startupReady = true; _loading = false; });
      }
      if (!content.isLoaded) {
        setState(() { _loading = false; });
      }
    } catch (error) {
      debugPrint('[Streamia/Library] attempt=$attempt failed after ${watch.elapsedMilliseconds}ms (${error.runtimeType})');
      if (mounted && attempt == _loadAttempt) {
        // A restore may have published the catalog just before a later
        // asynchronous step failed. Never display Retry for a ready library,
        // or leave the gate stranded with neither a retry nor a route.
        setState(() {
          _loading = false;
          if (content.isLoaded) {
            _progressPercent = 100;
            _completedPhases = 3;
            _startupReady = true;
            _loadFailed = false;
          } else {
            _loadFailed = true;
          }
        });
      }
    } finally {
      watch.stop();
      if (identical(_loadWatch, watch)) {
        debugPrint('[Streamia/Library] attempt=$attempt ended after ${watch.elapsedMilliseconds}ms; loaded=${content.isLoaded}');
        _loadWatch = null;
      }
    }
  }

  String _copy(BuildContext context, String de, String tr, String en) {
    final language = Localizations.localeOf(context).languageCode;
    return language == 'de' ? de : language == 'tr' ? tr : en;
  }

  @override
  Widget build(BuildContext context) {
    final libraryLoaded = context.watch<ContentProvider>().isLoaded;
    if (_startupReady && libraryLoaded) {
      return const _LandscapeDashboard();
    }
    if (!_loading && !_hasProfiles && !_loadFailed) {
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
                  Text('Streamia Player', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 22),
                  LinearProgressIndicator(
                    value: _progressPercent / 100,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 12),
                  Text('$_progressPercent %'),
                  if (_m3uCounts case final counts?) ...[
                    const SizedBox(height: 10),
                    Text(_copy(context,
                      'Erfasst: ${counts.$1} Sender · ${counts.$2} Filme · ${counts.$3} Serien',
                      'İşlenen: ${counts.$1} kanal · ${counts.$2} film · ${counts.$3} dizi',
                      'Parsed: ${counts.$1} channels · ${counts.$2} movies · ${counts.$3} series',
                    ), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 18),
                  Wrap(spacing: 18, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final phase in [
                      (0, _copy(context, 'Live-TV', 'Canlı TV', 'Live TV')),
                      (1, _copy(context, 'Filme', 'Filmler', 'Movies')),
                      (2, _copy(context, 'Serien', 'Diziler', 'Series')),
                    ])
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_completedPhases > phase.$1
                            ? Icons.check_circle : Icons.circle_outlined,
                            color: const Color(0xFF20D9EC), size: 18),
                        const SizedBox(width: 6),
                        Text(phase.$2),
                      ]),
                  ]),
                  const SizedBox(height: 20),
                  Text(switch (_loadStage) {
                    'profiles' => _copy(context, 'Playlist-Profile werden geladen…', 'Oynatma listesi profilleri yükleniyor…', 'Loading playlist profiles…'),
                    'local' => _copy(context, 'Gespeicherte Mediathek wird geöffnet…', 'Kayıtlı medya kitaplığı açılıyor…', 'Opening saved library…'),
                    _ => _copy(context, 'Playlist-Daten werden geladen…', 'Oynatma listesi verileri yükleniyor…', 'Loading playlist data…'),
                  }, textAlign: TextAlign.center),
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
                      MaterialPageRoute(
                        builder: (_) => const SetupScreen(returnToPreviousOnSuccess: true),
                      ),
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
    // The root gate has just verified this device. Refreshing here would
    // clear accessChecked, unmount this gate, and mount it again on pending.
    // Only an explicit user action should trigger another access check.
    if (!auth.devicePending || auth.deviceApproved ||
        !auth.hasAccountAccess || auth.error != null) {
      _dialogOpen = false;
      return;
    }
    await auth.loadActiveDevices();
    if (!mounted || !auth.devicePending || auth.deviceApproved ||
        !auth.hasAccountAccess || auth.error != null) {
      _dialogOpen = false;
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => Consumer<AuthProvider>(
          builder: (dialogContext, current, _) {
            final devices = current.activeDevices;
            // A refresh may have approved this installation while the dialog
            // was loading. Close the obsolete dialog instead of showing it.
            if (current.accessChecked &&
                (current.deviceApproved || !current.devicePending)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              });
              return const SizedBox.shrink();
            }
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
                    await current.refreshDeviceAndAccess();
                    if (dialogContext.mounted && current.devicePending &&
                        current.hasAccountAccess && current.error == null) {
                      await current.loadActiveDevices();
                    }
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
                if (!blocked && auth.accessDiagnostic != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(auth.accessDiagnostic!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  autofocus: true,
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
  bool _legalDialogOpen = false;

  @override
  Widget build(BuildContext context) {
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

      return const Scaffold(body: SizedBox.expand());
    }

    return widget.destination;
  }
}

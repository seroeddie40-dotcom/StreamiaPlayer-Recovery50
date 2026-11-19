import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/platform/tv_remote_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'screens/splash_screen.dart';
import 'core/platform/device_layout.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/content_provider.dart';
import 'providers/family_session_provider.dart';
import 'core/storage/prefs_service.dart';
import 'config/supabase_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Widget? _app;
  String? _failedStage;
  bool _slow = false;
  bool _starting = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    if (_starting || !mounted) return;
    setState(() {
      _starting = true;
      _failedStage = null;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _starting) setState(() => _slow = true);
    });
    try {
      final app = await _initializeApp();

      if (!mounted) return;

      setState(() {
        _app = app;
      });
    } catch (error, stackTrace) {
      debugPrint('Streamia startup failed (${error.runtimeType})');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _failedStage = error is _StartupFailure ? error.stage : 'APP';
      });
    } finally {
      _slowTimer?.cancel();
      _starting = false;
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _app ??
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TvRemoteNavigation.theme(ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
          )),
          shortcuts: DeviceLayout.isTelevision ? TvRemoteNavigation.shortcuts : null,
          home: _failedStage != null
              ? Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const StreamiaBrandLogo(size: 96),
                            const SizedBox(height: 20),
                            const Text('Streamia Player'),
                            const SizedBox(height: 12),
                            if (_failedStage != null) ...[
                              Text('Initialization failed ($_failedStage).',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                autofocus: true,
                                onPressed: _start,
                                child: const Text('Retry'),
                              ),
                            ] else ...[
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text('Still starting… Please wait.',
                                  textAlign: TextAlign.center),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )
               : Stack(
                  fit: StackFit.expand,
                  children: [
                    const SplashScreen(),
                    if (_slow)
                      const SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
        );
  }
}

class _StartupFailure implements Exception {
  final String stage;
  const _StartupFailure(this.stage);
  @override
  String toString() => 'Startup failed: $stage';
}

Future<T> _stage<T>(String name, Future<T> Function() operation) async {
  final watch = Stopwatch()..start();
  try {
    final result = await operation();
    debugPrint('Streamia startup $name OK ${watch.elapsedMilliseconds}ms');
    return result;
  } catch (error) {
    debugPrint('Streamia startup $name FAILED ${watch.elapsedMilliseconds}ms (${error.runtimeType})');
    throw _StartupFailure(name);
  }
}

Future<void> _initializeDeviceLayout() => _stage('DEVICE', _configureDeviceLayout);

Future<void> _configureDeviceLayout() async {
  await DeviceLayout.initialize();

  if (DeviceLayout.isTelevision) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    PaintingBinding.instance.imageCache.maximumSize = 120;

    PaintingBinding.instance.imageCache.maximumSizeBytes =
        32 * 1024 * 1024;
  }

  // Android TV already enforces landscape in MainActivity.
  if (DeviceLayout.isTelevision) return;

  // Orientation is a presentation preference, not an access prerequisite.
  try {
    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    ).timeout(const Duration(seconds: 2));
  } catch (error) {
    debugPrint('Streamia orientation request failed (${error.runtimeType})');
  }

}

Future<void>? _backendInitialization;

Future<void> _initializeBackend() => _stage('BACKEND', _configureBackend);

Future<void> _configureBackend() async {
  if (SupabaseConfig.isConfigured) {
    // Keep a timed-out initialization in flight rather than initializing twice.
    final pending = _backendInitialization ??= Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ).then<void>((_) {}, onError: (Object error, StackTrace stack) {
      _backendInitialization = null;
      Error.throwWithStackTrace(error, stack);
    });
    await pending.timeout(const Duration(seconds: 20));
  }
}

Future<SharedPreferences>? _storageInitialization;

Future<SharedPreferences> _loadPreferences() {
  return _storageInitialization ??= SharedPreferences.getInstance().then(
    (value) => value,
    onError: (Object error, StackTrace stack) {
      _storageInitialization = null;
      Error.throwWithStackTrace(error, stack);
    },
  );
}

Future<Widget> _initializeApp() async {
  SharedPreferences? prefs;
  await Future.wait<void>([
    _initializeDeviceLayout(),
    _stage('STORAGE', () async {
      prefs = await _loadPreferences()
          .timeout(const Duration(seconds: 10));
    }),
    _initializeBackend(),
  ]);

  final prefsService = PrefsService(prefs!);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(prefsService),
      ),
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(prefsService),
      ),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(prefsService),
      ),
      ChangeNotifierProvider(
        create: (_) => ContentProvider(
          maxInactiveCachedLibraries:
              DeviceLayout.isTelevision ? 0 : 2,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => FamilySessionProvider(),
      ),
    ],
    child: StreamiaApp(
      prefsService: prefsService,
    ),
  );
}

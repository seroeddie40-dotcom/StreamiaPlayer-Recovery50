import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
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
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    try {
      final app = await _initializeApp();

      if (!mounted) return;

      setState(() {
        _app = app;
      });
    } catch (error, stackTrace) {
      debugPrint('Streamia startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _app ??
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
          ),
          home: _failed
              ? const Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Streamia Player\n'
                          'Initialization failed. Please restart the app.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                )
              : const SplashScreen(),
        );
  }
}

Future<Widget> _initializeApp() async {
  await DeviceLayout.initialize().timeout(
    const Duration(seconds: 3),
  );

  if (DeviceLayout.isTelevision) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    PaintingBinding.instance.imageCache.maximumSize = 120;

    PaintingBinding.instance.imageCache.maximumSizeBytes =
        32 * 1024 * 1024;
  }

  await SystemChrome.setPreferredOrientations(
    DeviceLayout.isTelevision
        ? [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : [
            DeviceOrientation.portraitUp,
          ],
  ).timeout(
    const Duration(seconds: 3),
  );

  MediaKit.ensureInitialized();

  final prefs = await SharedPreferences.getInstance().timeout(
    const Duration(seconds: 5),
  );

  final prefsService = PrefsService(prefs);

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ).timeout(
      const Duration(seconds: 20),
    );
  }

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

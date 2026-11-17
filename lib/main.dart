
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/platform/device_layout.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/content_provider.dart';
import 'providers/family_session_provider.dart';
import 'core/storage/prefs_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Detect the physical device and apply its orientation before any network
  // initialization. A slow Supabase startup must not leave Android TV in portrait.
  await DeviceLayout.initialize();
  if (DeviceLayout.isTelevision) {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    PaintingBinding.instance.imageCache.maximumSize = 120;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  }
  await SystemChrome.setPreferredOrientations(
    DeviceLayout.isTelevision
        ? [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : [DeviceOrientation.portraitUp],
  );

  // Initialize the shared Supabase client before providers/screens are created.
  // The publishable key is public by design; RLS protects all user data.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final prefsService = PrefsService(prefs);

  runApp(
    MultiProvider(
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
            maxInactiveCachedLibraries: DeviceLayout.isTelevision ? 0 : 2,
          ),
        ),

        // Global family session for Live TV, VOD, Series,
        // Favorites, Search, History and Player.
        ChangeNotifierProvider(
          create: (_) => FamilySessionProvider(),
        ),
      ],
      child: StreamiaApp(prefsService: prefsService),
    ),
  );
}

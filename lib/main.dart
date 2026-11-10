import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/content_provider.dart';
import 'core/storage/prefs_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Initialize the shared Supabase client before providers/screens are created.
  // The publishable key is public by design; RLS protects all user data.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  
  // Standardmäßig Hochformat für das Setup
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final prefsService = PrefsService(prefs);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefsService)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefsService)),
        ChangeNotifierProvider(create: (_) => AuthProvider(prefsService)),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: StreamiaApp(prefsService: prefsService),
    ),
  );
}

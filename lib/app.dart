import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/content_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_disclaimer_screen.dart';
import 'core/storage/prefs_service.dart';
import 'dart:async';

class StreamiaApp extends StatelessWidget {
  final PrefsService prefsService;
  const StreamiaApp({super.key, required this.prefsService});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final contentProvider = context.watch<ContentProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Streamia Player',
      debugShowCheckedModeBanner: false,
      // Provide a consistent D-pad / keyboard traversal scope for every route,
      // including authentication, setup, dialogs and secondary screens.
      builder: (context, child) => FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: child ?? const SizedBox.shrink(),
      ),
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
      home: StartupGate(
        prefsService: prefsService,
        localeProvider: localeProvider,
        destination: _resolveHome(localeProvider, contentProvider, authProvider),
      ),
    );
  }

  Widget _resolveHome(LocaleProvider locale, ContentProvider content, AuthProvider auth) {
    if (!locale.hasSelectedLanguage) {
      return const LanguageSelectionScreen();
    }
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    if (!auth.accessChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.hasAccess) {
      return const PaywallScreen();
    }
    if (!content.isLoaded) {
      return const SetupScreen();
    }
    // Ab hier sind wir im Dashboard -> Querformat
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return const DashboardScreen();
  }
}


class StartupGate extends StatefulWidget {
  final PrefsService prefsService;
  final LocaleProvider localeProvider;
  final Widget destination;
  const StartupGate({super.key, required this.prefsService, required this.localeProvider, required this.destination});
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _splashFinished = false;
  bool _legalDialogOpen = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _splashFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashFinished) return const SplashScreen();
    // First launch order: splash -> language selection -> localized legal notice.
    if (!widget.localeProvider.hasSelectedLanguage) return widget.destination;
    if (!widget.prefsService.hasAcceptedCurrentLegalDisclaimer) {
      if (!_legalDialogOpen) {
        _legalDialogOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await Navigator.of(context).push<bool>(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => LegalDisclaimerScreen(
              prefs: widget.prefsService,
              requireAcceptance: true,
              languageCode: widget.localeProvider.locale.languageCode,
            ),
          ));
          if (mounted) setState(() => _legalDialogOpen = false);
        });
      }
      return const SplashScreen();
    }
    return widget.destination;
  }
}

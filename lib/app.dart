
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

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

    final showThemeButton =
        localeProvider.hasSelectedLanguage &&
        prefsService.hasAcceptedCurrentLegalDisclaimer;

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

      builder: (context, child) {
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),

              if (showThemeButton)
                const _GlobalThemeToggle(),
            ],
          ),
        );
      },

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

    if (!auth.hasAccess) {
      return const PaywallScreen();
    }

    if (!content.isLoaded) {
      return const SetupScreen();
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return const DashboardScreen();
  }
}

/// Globaler Theme-Button.
///
/// Der Button wird oberhalb der Navigator-Oberflaeche
/// dargestellt und bleibt damit auch beim Wechsel
/// zwischen normalen App-Routen erreichbar.
///
/// Fuer einen Vollbild-Videoplayer ist spaeter eine
/// separate Sichtbarkeitssteuerung erforderlich.
class _GlobalThemeToggle extends StatelessWidget {
  const _GlobalThemeToggle();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final isDark =
        themeProvider.themeMode == ThemeMode.dark;

    final languageCode =
        context.watch<LocaleProvider>()
            .locale
            .languageCode;

    final tooltip = _tooltip(
      languageCode,
      isDark,
    );

    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        left: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 8,
            right: 12,
          ),
          child: Material(
            color: isDark
                ? const Color(0xFF1A2942)
                : Colors.white,
            elevation: 5,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(50),
            child: IconButton(
              tooltip: tooltip,
              iconSize: 24,
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                side: BorderSide(
                  color: AppTheme.electricBlue
                      .withValues(alpha: 0.55),
                ),
              ),
              onPressed: () {
                context
                    .read<ThemeProvider>()
                    .toggleTheme();
              },
              icon: Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: isDark
                    ? const Color(0xFFFFD166)
                    : const Color(0xFF253B59),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltip(String languageCode, bool isDark) {
    switch (languageCode) {
      case 'de':
        return isDark
            ? 'Zum hellen Modus wechseln'
            : 'Zum dunklen Modus wechseln';

      case 'tr':
        return isDark
            ? 'Açık temaya geç'
            : 'Koyu temaya geç';

      case 'en':
        return isDark
            ? 'Switch to light mode'
            : 'Switch to dark mode';

      case 'ru':
        return isDark
            ? 'Включить светлую тему'
            : 'Включить тёмную тему';

      case 'ar':
        return isDark
            ? 'التبديل إلى الوضع الفاتح'
            : 'التبديل إلى الوضع الداكن';

      case 'pl':
        return isDark
            ? 'Włącz jasny motyw'
            : 'Włącz ciemny motyw';

      case 'es':
        return isDark
            ? 'Cambiar al modo claro'
            : 'Cambiar al modo oscuro';

      case 'fr':
        return isDark
            ? 'Passer au mode clair'
            : 'Passer au mode sombre';

      default:
        return isDark
            ? 'Switch to light mode'
            : 'Switch to dark mode';
    }
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
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _splashFinished = false;
  bool _legalDialogOpen = false;

  @override
  void initState() {
    super.initState();

    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        setState(() {
          _splashFinished = true;
        });
      }
    });
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


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

import 'screens/login_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_disclaimer_screen.dart';

/// Diagnostic error display for Flutter widget errors.
///
/// This is intended for test builds only.
/// It does not change Supabase permissions or device approval.
class _StreamiaDiagnosticError extends StatelessWidget {
  final FlutterErrorDetails details;

  const _StreamiaDiagnosticError({
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final message = details.exceptionAsString();

    final diagnostics = StringBuffer()
      ..writeln('STREAMIA PLAYER - DIAGNOSE')
      ..writeln()
      ..writeln('Fehler:')
      ..writeln(message)
      ..writeln()
      ..writeln('Stacktrace:')
      ..writeln(details.stack?.toString() ?? 'Nicht verfügbar');

    return Material(
      color: const Color(0xFF101827),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 700,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bug_report_rounded,
                    color: Colors.orangeAccent,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'STREAMIA - FEHLERDIAGNOSE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ein Flutter-Fehler wurde erkannt. '
                    'Bitte kopiere die Fehlermeldung '
                    'oder mache einen Screenshot.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202C40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: diagnostics.toString(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text(
                      'Fehlermeldung kopieren',
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

/// Installs a diagnostic widget for errors occurring
/// during Flutter widget building.
class _StreamiaDiagnostics {
  static bool _installed = false;

  static void install() {
    if (_installed) return;

    _installed = true;

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _StreamiaDiagnosticError(
        details: details,
      );
    };
  }
}

class StreamiaApp extends StatelessWidget {
  final PrefsService prefsService;

  const StreamiaApp({
    super.key,
    required this.prefsService,
  });

  @override
  Widget build(BuildContext context) {
    _StreamiaDiagnostics.install();

    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final contentProvider = context.watch<ContentProvider>();
    final authProvider = context.watch<AuthProvider>();

    final showThemeButton =
        localeProvider.hasSelectedLanguage &&
        prefsService.hasAcceptedCurrentLegalDisclaimer &&
        !contentProvider.isLoaded;

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
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _GlobalThemeToggle(),
                ),
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

    if (auth.devicePending || !auth.deviceApproved) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.pending,
      );
    }

    if (auth.requiresPayment) {
      return const PaywallScreen();
    }

    if (!auth.hasAccess) {
      return const _AccessStatusScreen(
        mode: _AccessStatusMode.error,
      );
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

enum _AccessStatusMode {
  pending,
  blocked,
  error,
}

class _AccessStatusScreen extends StatelessWidget {
  final _AccessStatusMode mode;

  const _AccessStatusScreen({
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final language =
        context.watch<LocaleProvider>().locale.languageCode;

    final isTurkish = language == 'tr';
    final isGerman = language == 'de';

    String title;
    String description;
    IconData symbol;

    switch (mode) {
      case _AccessStatusMode.pending:
        title = isTurkish
            ? 'Cihaz onayı bekleniyor'
            : isGerman
                ? 'Gerätefreigabe ausstehend'
                : 'Device approval pending';

        description = isTurkish
            ? 'Bu cihaz kaydedildi ancak henüz onaylanmadı. '
              'Onaylandıktan sonra yeniden kontrol edin.'
            : isGerman
                ? 'Dieses Gerät wurde registriert, ist aber '
                  'noch nicht freigegeben. Nach der Freigabe '
                  'kannst du den Status erneut prüfen.'
                : 'This device is registered but not yet '
                  'approved. Check again after approval.';

        symbol = Icons.hourglass_top_rounded;
        break;

      case _AccessStatusMode.blocked:
        title = isTurkish
            ? 'Cihaz erişimi engellendi'
            : isGerman
                ? 'Gerät nicht freigegeben'
                : 'Device access blocked';

        description = isTurkish
            ? 'Bu cihaz için erişim engellendi.'
            : isGerman
                ? 'Dieses Gerät wurde gesperrt oder abgelehnt.'
                : 'This device has been blocked or rejected.';

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
        actions: const [
          SizedBox(width: 56),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    symbol,
                    size: 64,
                    color: AppTheme.electricBlue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    description,
                    textAlign: TextAlign.center,
                  ),
                  if (auth.deviceId != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      'Device ID: ${auth.deviceId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: auth.isBusy
                        ? null
                        : () => auth.refreshDeviceAndAccess(),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      isTurkish
                          ? 'Tekrar kontrol et'
                          : isGerman
                              ? 'Erneut prüfen'
                              : 'Check again',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () => auth.logout(),
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

class _GlobalThemeToggle extends StatelessWidget {
  const _GlobalThemeToggle();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final isDark =
        themeProvider.themeMode == ThemeMode.dark;

    return SafeArea(
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
          borderRadius: BorderRadius.circular(50),
          child: IconButton(
            tooltip: isDark
                ? 'Light mode'
                : 'Dark mode',
            iconSize: 24,
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
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

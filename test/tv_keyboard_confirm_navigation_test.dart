
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/core/localization/app_localizations.dart';
import 'package:streamia_player/widgets/tv_text_keyboard.dart';

/// Provides already loaded translations synchronously.
/// This avoids waiting for asynchronous asset loading
/// while the test widget tree is being constructed.
class _TestLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  final AppLocalizations translations;

  const _TestLocalizationsDelegate(this.translations);

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == translations.locale.languageCode;
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(translations);
  }

  @override
  bool shouldReload(_TestLocalizationsDelegate old) {
    return !identical(translations, old.translations);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(
    WidgetTester tester,
    TextEditingController controller,
    VoidCallback onConfirmed,
  ) async {
    // Load the actual German translations before building the app.
    final translations = AppLocalizations(const Locale('de'));

    await tester.runAsync(() async {
      await translations.load();
    });

    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        locale: const Locale('de'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          _TestLocalizationsDelegate(translations),
          ...AppLocalizations.localizationsDelegates.skip(1),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TvTextKeyboard.show(
                context,
                controller: controller,
                languageCode: 'de',
                onConfirmed: onConfirmed,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final openButton = find.text('Open');

    if (openButton.evaluate().isEmpty) {
      debugPrint('STREAMIA TV LOCALIZATION CHECK');
      debugPrint(
        'MaterialApp: ${find.byType(MaterialApp).evaluate().length}',
      );
      debugPrint(
        'Scaffold: ${find.byType(Scaffold).evaluate().length}',
      );
      debugPrint(
        'Open: ${openButton.evaluate().length}',
      );
      debugDumpApp();
    }

    expect(
      openButton,
      findsOneWidget,
      reason: 'Localized test screen must be visible.',
    );

    await tester.tap(openButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets(
    'Confirm commits text and invokes next-field callback once',
    (tester) async {
      final controller = TextEditingController(text: 'old');
      addTearDown(controller.dispose);

      var calls = 0;

      await open(
        tester,
        controller,
        () => calls++,
      );

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(controller.text, 'old');

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'olda');
      expect(calls, 1);
    },
  );

  testWidgets(
    'Cancel does not invoke next-field callback',
    (tester) async {
      final controller = TextEditingController(text: 'old');
      addTearDown(controller.dispose);

      var calls = 0;

      await open(
        tester,
        controller,
        () => calls++,
      );

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'old');
      expect(calls, 0);
    },
  );
}

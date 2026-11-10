
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/core/localization/app_localizations.dart';
import 'package:streamia_player/widgets/tv_text_keyboard.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TextEditingController controller,
    VoidCallback onConfirmed,
  ) async {
    // Load the language asset before building the localized app.
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/lang/de.json');
    });

    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        locale: const Locale('de'),
        localizationsDelegates:
            AppLocalizations.localizationsDelegates
                .cast<LocalizationsDelegate<dynamic>>(),
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

    await tester.pump();
    await tester.pumpAndSettle();

    final openButton = find.text('Open');

    if (openButton.evaluate().isEmpty) {
      debugPrint('STREAMIA LOCALIZATION DIAGNOSTIC');
      debugPrint(
        'MaterialApp: ${find.byType(MaterialApp).evaluate().length}',
      );
      debugPrint(
        'Scaffold: ${find.byType(Scaffold).evaluate().length}',
      );
      debugPrint(
        'Open button: ${openButton.evaluate().length}',
      );
      debugDumpApp();
    }

    expect(
      openButton,
      findsOneWidget,
      reason: 'Localized test screen must finish loading.',
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

      await open(tester, controller, () => calls++);

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

      await open(tester, controller, () => calls++);

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'old');
      expect(calls, 0);
    },
  );
}

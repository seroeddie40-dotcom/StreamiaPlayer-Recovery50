
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/core/localization/app_localizations.dart';
import 'package:streamia_player/widgets/tv_text_keyboard.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TextEditingController controller,
    VoidCallback onConfirmed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        // Ensure a fresh Navigator and widget tree for every test.
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

    await tester.pumpAndSettle();

    expect(
      find.text('Open'),
      findsOneWidget,
      reason: 'The keyboard launch button must be visible.',
    );

    await tester.tap(find.text('Open'));
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

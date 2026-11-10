
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/core/localization/app_localizations.dart';
import 'package:streamia_player/widgets/tv_text_keyboard.dart';

void main() {
  Future<void> launch(
    WidgetTester tester,
    TextEditingController controller, {
    bool urlMode = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates:
            AppLocalizations.localizationsDelegates
                .cast<LocalizationsDelegate<dynamic>>(),
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TvTextKeyboard.show(
                  context,
                  controller: controller,
                  languageCode: 'de',
                  urlMode: urlMode,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'URL shortcuts are hidden for ordinary text',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      expect(find.text('http://'), findsNothing);
      expect(find.text('https://'), findsNothing);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'URL mode shows scheme shortcuts',
    (tester) async {
      final controller =
          TextEditingController(text: 'example.org');
      addTearDown(controller.dispose);

      await launch(
        tester,
        controller,
        urlMode: true,
      );

      expect(find.text('http://'), findsOneWidget);
      expect(find.text('https://'), findsOneWidget);

      await tester.ensureVisible(find.text('https://'));
      await tester.tap(find.text('https://'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'https://example.org');
    },
  );

  testWidgets(
    'Lowercase and uppercase work without shift',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'aA');
    },
  );

  testWidgets(
    'Keyboard commits only after confirmation',
    (tester) async {
      final controller =
          TextEditingController(text: 'old');
      addTearDown(controller.dispose);

      await launch(tester, controller);

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      expect(controller.text, 'old');

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'old');

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(controller.text, 'olda');
    },
  );

  testWidgets(
    'Focused key remains visible in compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(640, 420);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      final lastKey =
          find.widgetWithText(OutlinedButton, '#');

      expect(lastKey, findsOneWidget);

      final button =
          tester.widget<OutlinedButton>(lastKey);

      button.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(button.focusNode!.hasFocus, isTrue);

      final scrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      );

      expect(scrollable, findsOneWidget);

      final scrollPosition = tester.state<ScrollableState>(
        find.descendant(
          of: scrollable,
          matching: find.byType(Scrollable),
        ),
      ).position;

      expect(scrollPosition.pixels, greaterThan(0));
    },
  );

  testWidgets(
    'Escape discards edits',
    (tester) async {
      final controller =
          TextEditingController(text: 'unchanged');
      addTearDown(controller.dispose);

      await launch(tester, controller);

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.text, 'unchanged');
    },
  );

  testWidgets(
    'Remote Enter confirms focused action',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      await tester.tap(find.text('a').first);
      await tester.pumpAndSettle();

      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Übernehmen',
        ),
      );

      confirm.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(confirm.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(controller.text, 'a');
    },
  );

  testWidgets(
    'D-pad right changes focus without typing',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      final first = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'a'),
      );

      first.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(first.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.arrowRight,
      );
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        isNot(first.focusNode),
      );

      expect(controller.text, isEmpty);
    },
  );

  testWidgets(
    'Focus traversal follows defined order',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await launch(tester, controller);

      final lower =
          find.widgetWithText(OutlinedButton, 'a');
      final upper =
          find.widgetWithText(OutlinedButton, 'A');
      final cancel =
          find.widgetWithText(TextButton, 'Abbrechen');
      final confirm =
          find.widgetWithText(FilledButton, 'Übernehmen');

      expect(lower, findsOneWidget);
      expect(upper, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);

      NumericFocusOrder orderOf(Finder finder) {
        final ancestor = find.ancestor(
          of: finder,
          matching: find.byType(FocusTraversalOrder),
        );

        return tester
            .widget<FocusTraversalOrder>(ancestor.first)
            .order as NumericFocusOrder;
      }

      final lowerOrder = orderOf(lower);
      final upperOrder = orderOf(upper);
      final cancelOrder = orderOf(cancel);
      final confirmOrder = orderOf(confirm);

      expect(
        lowerOrder.order,
        lessThan(upperOrder.order),
      );
      expect(
        upperOrder.order,
        lessThan(cancelOrder.order),
      );
      expect(
        cancelOrder.order,
        lessThan(confirmOrder.order),
      );
    },
  );

  testWidgets(
    'Left and right stay inside action buttons',
    (tester) async {
      final controller =
          TextEditingController(text: 'keep');
      addTearDown(controller.dispose);

      await launch(tester, controller);

      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Abbrechen'),
      );

      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Übernehmen',
        ),
      );

      cancel.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(
        LogicalKeyboardKey.arrowLeft,
      );
      await tester.pumpAndSettle();

      expect(confirm.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.arrowRight,
      );
      await tester.pumpAndSettle();

      expect(cancel.focusNode!.hasFocus, isTrue);
      expect(controller.text, 'keep');
    },
  );

  testWidgets(
    'Down at confirm stays inside modal',
    (tester) async {
      final controller =
          TextEditingController(text: 'keep');
      addTearDown(controller.dispose);

      await launch(tester, controller);

      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Übernehmen',
        ),
      );

      confirm.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(
        LogicalKeyboardKey.arrowDown,
      );
      await tester.pumpAndSettle();

      expect(confirm.focusNode!.hasFocus, isTrue);
      expect(controller.text, 'keep');
    },
  );

  testWidgets(
    'URL scheme replaces existing scheme',
    (tester) async {
      final controller = TextEditingController(
        text: 'http://example.com:8080/live',
      );
      addTearDown(controller.dispose);

      await launch(
        tester,
        controller,
        urlMode: true,
      );

      await tester.ensureVisible(find.text('https://'));
      await tester.tap(find.text('https://'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        'https://example.com:8080/live',
      );
    },
  );

  testWidgets(
    'URL shortcut adds scheme to hostname',
    (tester) async {
      final controller =
          TextEditingController(text: 'example.com:8080');
      addTearDown(controller.dispose);

      await launch(
        tester,
        controller,
        urlMode: true,
      );

      await tester.ensureVisible(find.text('http://'));
      await tester.tap(find.text('http://'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        'http://example.com:8080',
      );
    },
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/core/localization/app_localizations.dart';
import 'package:streamia_player/core/platform/device_layout.dart';
import 'package:streamia_player/widgets/voice_input_field.dart';

class _LoadedDelegate extends LocalizationsDelegate<AppLocalizations> {
  final AppLocalizations translations;
  const _LoadedDelegate(this.translations);

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'de';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(translations);

  @override
  bool shouldReload(_LoadedDelegate old) => old.translations != translations;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TextEditingController controller;
  late FocusNode focus;
  late bool previousTv;
  String? submitted;

  setUp(() {
    previousTv = DeviceLayout.isTelevision;
    DeviceLayout.isTelevision = true;
    controller = TextEditingController(text: 'Original');
    focus = FocusNode();
    submitted = null;
  });

  tearDown(() {
    DeviceLayout.isTelevision = previousTv;
    controller.dispose();
    focus.dispose();
  });

  Future<void> launch(WidgetTester tester, {bool secret = false,
      bool mobile = false, TextInputType type = TextInputType.text}) async {
    DeviceLayout.isTelevision = !mobile;
    final translations = AppLocalizations(const Locale('de'));
    await tester.runAsync(() async { await translations.load(); });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _LoadedDelegate(translations),
        ...AppLocalizations.localizationsDelegates.skip(1),
      ],
      home: Scaffold(body: Center(child: VoiceInputField(
        controller: controller,
        focusNode: focus,
        appLanguageCode: 'de',
        decoration: const InputDecoration(labelText: 'Test input'),
        keyboardType: type,
        credentialMode: true,
        secret: secret,
        obscureText: secret,
        onSubmitted: (value) => submitted = value,
      ))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('TV remote opens native editable input', (tester) async {
    await launch(tester);
    expect(find.byType(TextField), findsNothing);
    await open(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField), 'MixedCase123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(controller.text, 'MixedCase123');
    expect(submitted, 'MixedCase123');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancel discards unconfirmed TV input', (tester) async {
    await launch(tester);
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Discard');
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Original');
    expect(submitted, isNull);
  });

  testWidgets('TV credentials disable correction and suggestions', (tester) async {
    await launch(tester, secret: true);
    await open(tester);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.obscureText, isTrue);
    expect(input.autocorrect, isFalse);
    expect(input.enableSuggestions, isFalse);
    expect(input.enableIMEPersonalizedLearning, isFalse);
    expect(input.textCapitalization, TextCapitalization.none);
  });

  testWidgets('TV URL uses URL input type', (tester) async {
    await launch(tester, type: TextInputType.url);
    await open(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.url);
  });

  testWidgets('Mobile retains direct text field without TV dialog', (tester) async {
    await launch(tester, mobile: true);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mobile');
    await tester.pump();
    expect(controller.text, 'Mobile');
    expect(find.byType(AlertDialog), findsNothing);
  });
}

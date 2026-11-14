
import 'package:flutter/material.dart';

import '../core/storage/prefs_service.dart';

class LocaleProvider extends ChangeNotifier {
  final PrefsService _prefs;

  late Locale _locale;
  late bool _hasSelected;

  static const List<String> supportedLanguageCodes = [
    'de',
    'tr',
    'en',
    'ru',
    'pl',
    'es',
    'fr',
    'ar',
  ];

  LocaleProvider(this._prefs) {
    final savedCode = _prefs.locale;

    final deviceCode = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .languageCode;

    final initialCode = _prefs.hasSelectedLanguage
        ? savedCode
        : (supportedLanguageCodes.contains(deviceCode)
            ? deviceCode
            : 'en');

    _locale = Locale(
      supportedLanguageCodes.contains(initialCode)
          ? initialCode
          : 'en',
    );

    _hasSelected = _prefs.hasSelectedLanguage;
  }

  Locale get locale => _locale;

  bool get hasSelectedLanguage => _hasSelected;

  bool get isLanguageSupported =>
      supportedLanguageCodes.contains(_locale.languageCode);

  Future<void> setLocale(String code) async {
    if (!supportedLanguageCodes.contains(code)) {
      return;
    }

    final alreadySelected =
        _locale.languageCode == code && _hasSelected;

    if (alreadySelected) {
      return;
    }

    _locale = Locale(code);
    _hasSelected = true;

    // Update the interface immediately.
    notifyListeners();

    // Persist the selection for future app launches.
    await _prefs.setLocale(code);
    await _prefs.setLanguageSelected();
  }
}

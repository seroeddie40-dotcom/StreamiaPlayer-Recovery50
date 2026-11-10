import 'package:flutter/material.dart';
import '../core/storage/prefs_service.dart';

class LocaleProvider extends ChangeNotifier {
  final PrefsService _prefs;
  late Locale _locale;
  late bool _hasSelected;

  static const supportedLanguageCodes = ['de', 'tr', 'en', 'ru', 'pl', 'es', 'fr', 'ar'];

  LocaleProvider(this._prefs) {
    final saved = _prefs.locale;
    final deviceCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final initialCode = _prefs.hasSelectedLanguage
        ? saved
        : (supportedLanguageCodes.contains(deviceCode) ? deviceCode : 'en');
    _locale = Locale(supportedLanguageCodes.contains(initialCode) ? initialCode : 'en');
    _hasSelected = _prefs.hasSelectedLanguage;
  }

  Locale get locale => _locale;
  bool get hasSelectedLanguage => _hasSelected;

  Future<void> setLocale(String code) async {
    _locale = Locale(code);
    _hasSelected = true;
    await _prefs.setLocale(code);
    await _prefs.setLanguageSelected();
    notifyListeners(); // Wichtig: App neu rendern
  }
}

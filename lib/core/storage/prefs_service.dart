import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  final SharedPreferences _prefs;
  PrefsService(this._prefs);

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale';
  static const _languageSelectedKey = 'language_selected';
  static const _macKey = 'mac_address';
  static const _pinKey = 'parental_pin';
  static const _lockedFoldersKey = 'locked_folders';
  static const legalDisclaimerVersion = '2026-11-08-v1';
  static const _legalVersionKey = 'legal_disclaimer_version';
  static const _legalAcceptedAtKey = 'legal_disclaimer_accepted_at';
  static const _legalLanguageKey = 'legal_disclaimer_language';

  String? getString(String key) => _prefs.getString(key);

  String get themeMode => _prefs.getString(_themeKey) ?? 'dark';
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);

  String get locale => _prefs.getString(_localeKey) ?? 'en';
  Future<void> setLocale(String code) => _prefs.setString(_localeKey, code);

  bool get hasSelectedLanguage => _prefs.getBool(_languageSelectedKey) ?? false;
  bool get hasAcceptedCurrentLegalDisclaimer =>
      _prefs.getString(_legalVersionKey) == legalDisclaimerVersion;
  String? get legalDisclaimerAcceptedAt => _prefs.getString(_legalAcceptedAtKey);
  String? get legalDisclaimerAcceptedLanguage => _prefs.getString(_legalLanguageKey);
  Future<void> setLegalDisclaimerAccepted(String languageCode) async {
    await _prefs.setString(_legalVersionKey, legalDisclaimerVersion);
    await _prefs.setString(_legalLanguageKey, languageCode);
    await _prefs.setString(_legalAcceptedAtKey, DateTime.now().toUtc().toIso8601String());
  }
  Future<void> setLanguageSelected() =>
      _prefs.setBool(_languageSelectedKey, true);

  String? get macAddress => _prefs.getString(_macKey);
  Future<void> setMacAddress(String mac) => _prefs.setString(_macKey, mac);

  String? get parentalPin => _prefs.getString(_pinKey);
  Future<void> setParentalPin(String pin) => _prefs.setString(_pinKey, pin);

  List<String> get lockedFolders =>
      _prefs.getStringList(_lockedFoldersKey) ?? [];
  Future<void> setLockedFolders(List<String> folders) =>
      _prefs.setStringList(_lockedFoldersKey, folders);

  Future<void> clear() => _prefs.clear();
}

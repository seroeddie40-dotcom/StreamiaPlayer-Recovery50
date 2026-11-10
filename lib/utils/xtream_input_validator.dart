/// Validates user-supplied Xtream credentials before making network requests.
/// Never includes credentials in error messages.
class XtreamInputValidator {
  static String? serverError(String value) {
    final input = value.trim();
    if (input.isEmpty) return 'Bitte eine Serveradresse eingeben.';
    final uri = Uri.tryParse(input);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return 'Serveradresse muss mit http:// oder https:// beginnen und einen gültigen Host enthalten.';
    }
    if (uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      return 'Bitte nur die Serveradresse mit optionalem Port eingeben, ohne Pfad oder Parameter.';
    }
    if (uri.port < 0 || uri.port > 65535) return 'Ungültiger Serverport.';
    return null;
  }

  static String? usernameError(String value) =>
      value.trim().isEmpty ? 'Bitte einen Benutzernamen eingeben.' : null;

  static String? passwordError(String value) =>
      value.isEmpty ? 'Bitte ein Passwort eingeben.' : null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/utils/xtream_input_validator.dart';

void main() {
  test('valid server addresses with optional port', () {
    expect(XtreamInputValidator.serverError('https://example.com:8080'), isNull);
    expect(XtreamInputValidator.serverError('http://example.com'), isNull);
  });
  test('rejects incomplete or unsafe server addresses', () {
    for (final input in ['', 'example.com', 'ftp://example.com',
      'https://user:secret@example.com', 'https://example.com/player_api.php',
      'https://example.com/?token=secret']) {
      expect(XtreamInputValidator.serverError(input), isNotNull);
    }
  });
  test('username and password must be provided', () {
    expect(XtreamInputValidator.usernameError('  '), isNotNull);
    expect(XtreamInputValidator.passwordError(''), isNotNull);
    expect(XtreamInputValidator.passwordError(' secret '), isNull);
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player lazy lists retain focused-row visibility support', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    expect(source.contains('Scrollable.ensureVisible('), isTrue);
    expect(source.contains('_keepFocusedNavigationRowVisible(rowContext, focused)'), isTrue);
    expect(source.contains('autofocus: i == _currentEpisode'), isTrue);
  });
}

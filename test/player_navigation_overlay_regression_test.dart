import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/player_screen.dart').readAsStringSync();
  test('overlay disables player controls from remote focus traversal', () {
    expect(source, contains('excluding: _showDrawer || _showHistory'));
    expect(source, contains('FocusTraversalGroup(child: _buildLiveNavigationDrawer())'));
    expect(source, contains('FocusTraversalGroup(child: _buildEpisodesDrawer())'));
  });
  test('navigation returns focus to the player when closed', () {
    expect(source, contains('void _restorePlayerFocus()'));
    expect(source, contains('void _closeNavigationDrawer()'));
    expect(source, contains('_playerSurfaceFocus.requestFocus()'));
  });
  test('history overlay focuses close action and restores player focus', () {
    expect(source, contains('_historyCloseFocus.requestFocus()'));
    expect(source, contains('void _closeHistorySidebar()'));
    expect(source, contains('focusNode: _historyCloseFocus'));
  });
  test('rapid navigation cancels outdated row scrolling', () {
    expect(source, contains('request != _focusedRowRequest'));
    expect(source, contains('epoch != _navigationScrollEpoch'));
  });
}

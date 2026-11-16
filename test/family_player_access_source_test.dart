import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player revokes streams on family and library changes', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    expect(source.contains('_familySession.addListener(_onFamilySessionChanged);'), isTrue);
    expect(source.contains('_contentProvider.addListener(_onFamilySessionChanged);'), isTrue);
    expect(source.contains('_familySession.removeListener(_onFamilySessionChanged);'), isTrue);
    expect(source.contains('_contentProvider.removeListener(_onFamilySessionChanged);'), isTrue);
    expect(source.contains('++_streamLoadGeneration;'), isTrue);
  });

  test('history and progress do not record revoked playback', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final history = source.substring(source.indexOf('void _recordCurrentEpisodeHistory('),
        source.indexOf('// Detect streams that silently stop'));
    final progress = source.substring(source.indexOf('Future<void> _saveProgress() async'),
        source.indexOf('KeyEventResult _handleRemoteKey'));
    expect(history.contains('_playbackRevoked || !_isCurrentStreamAuthorized()'), isTrue);
    expect(progress.contains('_playbackRevoked || !_isCurrentStreamAuthorized()'), isTrue);
    expect(source.contains('if (!mounted || _playbackRevoked || !_isCurrentStreamAuthorized()) return;'), isTrue);
  });
}

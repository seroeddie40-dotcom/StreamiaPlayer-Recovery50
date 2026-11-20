import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffering timeout remains active even if playing becomes false', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('void _checkPlaybackStall()');
    final end = source.indexOf('void _handlePlaybackFailure()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final monitor = source.substring(start, end);
    expect(monitor.indexOf('if (_buffering)'), lessThan(monitor.indexOf('if (!_playing) return;')));
    expect(monitor, contains('_bufferingTimeout'));
    expect(monitor, contains('if (widget.isLive)'));
    expect(monitor.indexOf('if (widget.isLive)'), lessThan(monitor.indexOf('final last = _lastPlaybackProgressAt;')));
  });

  test('stable playback timer excludes buffering intervals', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    expect(source, contains('if (!_buffering) _stablePlaybackStartedAt ??= DateTime.now();'));
    expect(source, contains('if (_playing) _stablePlaybackStartedAt ??= DateTime.now();'));
    expect(source, contains('if (buffering) {\n        _stablePlaybackStartedAt = null;'));
  });

  test('duplicate playing events do not refresh VOD stall clock', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('_playSub = _player.stream.playing.listen');
    final end = source.indexOf('_bufferingSub =', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final listener = source.substring(start, end);
    expect(listener, contains('final wasPlaying = _playing;'));
    expect(listener, contains('if (!wasPlaying) _lastPlaybackProgressAt = DateTime.now();'));
  });

  test('permission revocation stops after pending media opens', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('void _onFamilySessionChanged()');
    final end = source.indexOf('bool _canPlayChannel(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final revocation = source.substring(start, end);
    expect(revocation, contains('++_streamLoadGeneration'));
    expect(revocation, contains('final previousOpen = _openQueue;'));
    expect(revocation, contains('await previousOpen.catchError'));
    expect(revocation.indexOf('await previousOpen.catchError'),
        lessThan(revocation.indexOf('await _player.stop()')));
    expect(revocation, contains('_openQueue = revocation.future;'));
  });

  test('channel changes invalidate prior opens and retries', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('void _switchLiveChannel(');
    final end = source.indexOf('void _closeNavigationDrawerIfOpen()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final change = source.substring(start, end);
    expect(change, contains('++_streamLoadGeneration'));
    expect(change, contains('_reconnectTimer?.cancel()'));
    expect(change, contains('_bufferingStartedAt = null'));
    expect(change, contains('_activeChannel = channel'));
  });

  test('player disposal waits for pending open and blocks new opens', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    expect(source, contains('if (_playerDisposalStarted || !mounted) return;'));
    expect(source, contains('final pendingOpens = _openQueue;'));
    expect(source, contains('unawaited(_disposePlayerAfterOpens(pendingOpens));'));
    final start = source.indexOf('Future<void> _disposePlayerAfterOpens(');
    final end = source.indexOf('void dispose()', start);
    final cleanup = source.substring(start, end);
    expect(cleanup, contains('await pendingOpens;'));
    expect(cleanup, isNot(contains('pendingOpens.timeout(')));
    expect(cleanup.indexOf('await pendingOpens;'),
        lessThan(cleanup.indexOf('await _player.dispose()')));
  });

  test('unauthorized stream stop is serialized after pending opens', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadStream(');
    final end = source.indexOf('void _retryPlaybackManually()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final loader = source.substring(start, end);
    final unauthorized = loader.substring(
        loader.indexOf('if (!permitted) {'), loader.indexOf('final url = _currentUrl;'));
    expect(unauthorized, contains('final previousOpen = _openQueue;'));
    expect(unauthorized, contains('_openQueue = stopping.future;'));
    expect(unauthorized.indexOf('await previousOpen.catchError'),
        lessThan(unauthorized.indexOf('await _player.stop()')));
    expect(unauthorized, contains('stopping.complete();'));
  });

  test('stream open queue also protects post-open seek and disposal', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadStream(');
    final end = source.indexOf('void _retryPlaybackManually()', start);
    final loader = source.substring(start, end);
    expect(loader.indexOf('await _player.open(Media(url));'),
        lessThan(loader.indexOf('await _player.seek(resumeAt);')));
    expect(loader.indexOf('await _player.seek(resumeAt);'),
        lessThan(loader.lastIndexOf('opening.complete();')));
    expect(loader, contains('!_playerDisposalStarted && _isCurrentStreamAuthorized()'));
    expect(loader, contains('} finally {\n      opening.complete();'));
  });

  test('late native errors cannot retry revoked or disposed playback', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('void _handlePlaybackFailure()');
    final end = source.indexOf('void _onFamilySessionChanged()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final handler = source.substring(start, end);
    expect(handler, contains('_playerDisposalStarted'));
    expect(handler, contains('_playbackRevoked'));
    expect(handler, contains('!_isCurrentStreamAuthorized()'));
  });

  test('authorization revocation after open cannot deadlock its own queue', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadStream(');
    final end = source.indexOf('void _retryPlaybackManually()', start);
    final loader = source.substring(start, end);
    expect(loader, contains('var revokeAfterOpen = false;'));
    expect(loader, contains('revokeAfterOpen = true;'));
    final completion = loader.lastIndexOf('opening.complete();');
    final revocation = loader.lastIndexOf('_onFamilySessionChanged();');
    expect(completion, greaterThan(0));
    expect(revocation, greaterThan(completion));
  });

}

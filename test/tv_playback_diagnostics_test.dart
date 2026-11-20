import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/services/tv_playback_diagnostics.dart';

void main() {
  group('TV playback diagnostics', () {
    test('disabled recorder retains no playback events', () {
      final diagnostics = TvPlaybackDiagnostics(enabled: false);
      diagnostics.streamOpened(reconnect: false);
      diagnostics.playing(true);
      diagnostics.buffering(true);
      diagnostics.failure('native-player-error');
      expect(diagnostics.report, 'TV playback diagnostics disabled');
    });

    test('captures playback and buffering state without credentials', () {
      final diagnostics = TvPlaybackDiagnostics(enabled: true);
      diagnostics.streamOpened(reconnect: false);
      diagnostics.playing(true);
      diagnostics.buffering(true);
      diagnostics.buffering(false);
      diagnostics.failure('https://user:password@example.com/live');
      final report = diagnostics.report;
      expect(report, contains('generation=1'));
      expect(report, contains('playing=true'));
      expect(report, contains('bufferEvents=1'));
      expect(report, contains('failures=1'));
      expect(report, contains('failure=other'));
      expect(report, isNot(contains('password')));
      expect(report, isNot(contains('example.com')));
    });

    test('keeps at most 80 event entries', () {
      final diagnostics = TvPlaybackDiagnostics(enabled: true);
      diagnostics.streamOpened(reconnect: false);
      for (var i = 0; i < 120; i++) {
        diagnostics.playing(i.isEven);
      }
      final lines = diagnostics.report.split('\n');
      // Eight header/counter lines plus at most 80 event lines.
      expect(lines.length, lessThanOrEqualTo(88));
    });

    test('new stream resets current counters', () {
      final diagnostics = TvPlaybackDiagnostics(enabled: true);
      diagnostics.streamOpened(reconnect: false);
      diagnostics.failure('native-player-error');
      diagnostics.buffering(true);
      diagnostics.streamOpened(reconnect: true);
      expect(diagnostics.report, contains('generation=2'));
      expect(diagnostics.report, contains('failures=0'));
      expect(diagnostics.report, contains('bufferEvents=0'));
    });
  });
}

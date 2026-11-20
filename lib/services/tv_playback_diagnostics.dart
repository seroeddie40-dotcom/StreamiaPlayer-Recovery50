import 'package:flutter/foundation.dart';

/// Bounded, credential-free playback event recorder for Android TV.
///
/// Does not retain stream URLs, titles, account IDs, or raw native errors.
/// Recording is event-driven: it adds no polling, timers, or network traffic.
class TvPlaybackDiagnostics {
  TvPlaybackDiagnostics({required this.enabled});

  final bool enabled;
  final Stopwatch _clock = Stopwatch()..start();
  static const int _maxEvents = 80;
  final List<String> _events = <String>[];
  int _generation = 0;
  int _bufferEvents = 0;
  int _failures = 0;
  bool? _lastPlaying;
  bool? _lastBuffering;
  Duration? _bufferingSince;
  int _totalBufferMs = 0;

  /// Text that can later be exposed by an in-app diagnostic screen.
  /// Contains only elapsed times, counters and fixed event codes.
  String get report {
    if (!enabled) return 'TV playback diagnostics disabled';
    final activeBufferMs = _bufferingSince == null
        ? 0
        : (_clock.elapsed - _bufferingSince!).inMilliseconds;
    return <String>[
      'Streamia TV playback diagnostics',
      'elapsedMs=${_clock.elapsedMilliseconds}',
      'generation=$_generation',
      'bufferEvents=$_bufferEvents',
      'totalBufferMs=${_totalBufferMs + activeBufferMs}',
      'failures=$_failures',
      'playing=${_lastPlaying ?? 'unknown'}',
      'buffering=${_lastBuffering ?? 'unknown'}',
      ..._events,
    ].join('\n');
  }

  void streamOpened({required bool reconnect}) {
    if (!enabled) return;
    _generation++;
    _lastPlaying = null;
    _lastBuffering = null;
    _bufferingSince = null;
    _bufferEvents = 0;
    _failures = 0;
    _totalBufferMs = 0;
    _record('open reconnect=$reconnect');
  }

  void playing(bool value) {
    if (!enabled || _lastPlaying == value) return;
    _lastPlaying = value;
    _record('playing=$value');
  }

  void buffering(bool value) {
    if (!enabled || _lastBuffering == value) return;
    _lastBuffering = value;
    if (value) {
      _bufferEvents++;
      _bufferingSince = _clock.elapsed;
      _record('buffering=start count=$_bufferEvents');
    } else {
      final durationMs = _bufferingSince == null
          ? -1
          : (_clock.elapsed - _bufferingSince!).inMilliseconds;
      if (durationMs >= 0) _totalBufferMs += durationMs;
      _bufferingSince = null;
      _record('buffering=end durationMs=$durationMs');
    }
  }

  void failure(String reason) {
    if (!enabled) return;
    // Do not retain caller-supplied strings: native errors may contain URLs.
    const safeReasons = <String>{
      'native-player-error',
      'buffering-timeout',
      'playback-stall',
    };
    _failures++;
    _record('failure=${safeReasons.contains(reason) ? reason : 'other'}');
  }

  void _record(String event) {
    if (!enabled) return;
    final line = 'generation=$_generation '
        'elapsedMs=${_clock.elapsedMilliseconds} $event';
    _events.add(line);
    if (_events.length > _maxEvents) _events.removeAt(0);
    if (kDebugMode) debugPrint('[StreamiaTVPlayback] $line');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Controls the native Android Media3 PlatformView registered by MainActivity.
/// This widget is Android-only. It is not automatically used by PlayerScreen.
class TvMedia3View extends StatefulWidget {
  const TvMedia3View({super.key, required this.url, this.reloadToken = 0, this.onState, this.onError});

  final String url;
  /// Changes on explicit reloads, even if the stream URL is unchanged.
  final int reloadToken;
  final void Function(int state, bool playing)? onState;
  final void Function(String errorCode)? onError;

  @override
  State<TvMedia3View> createState() => _TvMedia3ViewState();
}

class _TvMedia3ViewState extends State<TvMedia3View> {
  MethodChannel? _channel;
  int _generation = 0;
  int? _nativeGeneration;
  bool _waitingForOpen = false;
  // Serialize native open/stop requests on the same PlatformView.
  Future<void> _openQueue = Future<void>.value();
  // A delayed snapshot must never overwrite a newer native state event.
  bool _stateDeliveredForGeneration = false;

  @override
  void didUpdateWidget(covariant TvMedia3View oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.reloadToken != widget.reloadToken) {
      _open(widget.url);
    }
  }

  void _open(String url) {
    final generation = ++_generation;
    // Mark the pending switch immediately so old native events are ignored.
    _nativeGeneration = null;
    _stateDeliveredForGeneration = false;
    _waitingForOpen = url.isNotEmpty;
    // Only the newest request is executed after a prior native call completes.
    // Avoid overlapping stop/open requests and redundant decoder resets.
    _openQueue = _openQueue.then((_) async {
      if (!mounted || generation != _generation) return;
      await _performOpen(url, generation);
    }).catchError((Object _) {
      // A failed earlier operation must not block the next channel switch.
    });
  }

  Future<void> _performOpen(String url, int generation) async {
    final channel = _channel;
    if (channel == null || !mounted || generation != _generation) return;
    try {
      if (url.isEmpty) {
        await channel.invokeMethod<void>('stop');
        if (mounted && generation == _generation) _waitingForOpen = false;
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
          // An invalid replacement must not leave the previous channel playing.
          await channel.invokeMethod<void>('stop');
          if (mounted && generation == _generation) {
            _waitingForOpen = false;
            widget.onError?.call('INVALID_URL');
          }
          return;
        }
        final nativeGeneration = await channel.invokeMethod<int>(
          'open', <String, Object>{'url': url});
        if (mounted && generation == _generation) {
          _nativeGeneration = nativeGeneration;
          _waitingForOpen = false;
          // Initial IDLE/BUFFERING callbacks may have occurred synchronously
          // during native open(), before its generation was acknowledged.
          // Reconcile once without creating a second player or timer.
          if (nativeGeneration != null) {
            try {
              final snapshot = await channel.invokeMapMethod<String, dynamic>(
                'snapshot',
              );
              if (mounted && generation == _generation &&
                  _nativeGeneration == nativeGeneration &&
                  !_stateDeliveredForGeneration && snapshot != null &&
                  snapshot['generation'] == nativeGeneration) {
                final state = snapshot['state'];
                final playing = snapshot['playing'];
                if (state is int && playing is bool) {
                  _stateDeliveredForGeneration = true;
                  widget.onState?.call(state, playing);
                }
              }
            } catch (_) {
              // Normal native state callbacks and the startup watchdog remain
              // active if an older platform implementation lacks snapshot.
            }
          }
        }
      }
    } on PlatformException catch (e) {
      if (mounted && generation == _generation) {
        _waitingForOpen = false;
        // Activity.onPause may race a queued platform-channel open. This is
        // an OS lifecycle suspension, not a broken stream or decoder. The
        // owning screen reopens the current stream on lifecycle resume.
        // Reporting it as a playback failure would consume retry attempts
        // and could leave the player stuck in its manual-retry state.
        if (e.code != 'APP_BACKGROUND' &&
            e.code != 'STALE_OWNER' &&
            e.code != 'DISPOSED') {
          widget.onError?.call(e.code);
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _waitingForOpen = false;
        widget.onError?.call('CHANNEL_FAILURE');
      }
    }
  }

  void _created(int id) {
    final channel = MethodChannel('com.streamia/tv_media3_view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      final data = call.arguments;
      // Discard events from the previous stream, including events queued
      // while a new open is awaiting its native acknowledgement.
      if (data is! Map || _waitingForOpen) return;
      final eventGeneration = data['generation'];
      if (eventGeneration is! int ||
          _nativeGeneration == null ||
          eventGeneration != _nativeGeneration) return;
      if (call.method == 'state' && data is Map) {
        final state = data['state'];
        final playing = data['playing'];
        if (state is int && playing is bool) {
          _stateDeliveredForGeneration = true;
          widget.onState?.call(state, playing);
        }
      } else if (call.method == 'error' && data is Map) {
        widget.onError?.call(data['code']?.toString() ?? 'UNKNOWN');
      }
    });
    _open(widget.url);
  }

  @override
  void dispose() {
    ++_generation;
    _nativeGeneration = null;
    _stateDeliveredForGeneration = false;
    _waitingForOpen = false;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      // Native PlatformView owns its player and releases it on disposal.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.expand();
    }
    return AndroidView(
      viewType: 'com.streamia/tv_media3_view',
      onPlatformViewCreated: _created,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}

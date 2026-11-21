import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Controls the native Android Media3 PlatformView registered by MainActivity.
/// This widget is Android-only. It is not automatically used by PlayerScreen.
class TvMedia3View extends StatefulWidget {
  const TvMedia3View({super.key, required this.url, this.onState, this.onError});

  final String url;
  final void Function(int state, bool playing)? onState;
  final void Function(String errorCode)? onError;

  @override
  State<TvMedia3View> createState() => _TvMedia3ViewState();
}

class _TvMedia3ViewState extends State<TvMedia3View> {
  MethodChannel? _channel;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant TvMedia3View oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _open(widget.url);
    }
  }

  Future<void> _open(String url) async {
    final channel = _channel;
    if (channel == null) return;
    final generation = ++_generation;
    try {
      if (url.isEmpty) {
        await channel.invokeMethod<void>('stop');
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
          widget.onError?.call('INVALID_URL');
          return;
        }
        await channel.invokeMethod<void>('open', <String, Object>{'url': url});
      }
    } on PlatformException catch (e) {
      if (mounted && generation == _generation) {
        widget.onError?.call(e.code);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
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
      if (call.method == 'state' && data is Map) {
        final state = data['state'];
        final playing = data['playing'];
        if (state is int && playing is bool) {
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

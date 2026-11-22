#!/usr/bin/env python3
"""Static regression: invalid replacement cannot retain previous TV playback."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / 'lib/services/tv_media3_controller.dart').read_text()
invalid = source.index("widget.onError?.call('INVALID_URL')")
stop = source.rfind("await channel.invokeMethod<void>('stop');", 0, invalid)
assert stop != -1, 'Invalid URL must stop the previous native stream'
assert invalid - stop < 350, 'Stop must precede invalid-URL notification locally'
assert 'uri.host.isEmpty' in source, 'Require an HTTP(S) host'
assert 'if (!mounted || generation != _generation) return;' in source, 'Discard queued opens after disposal or switch'
assert 'channel.setMethodCallHandler(null);' in source, 'Detach callbacks on disposal'
print('PASS: invalid switch stops native playback and queued callbacks remain guarded')

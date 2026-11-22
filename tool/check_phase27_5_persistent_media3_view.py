#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'lib/screens/player_screen.dart').read_text()
d=(root/'lib/services/tv_media3_controller.dart').read_text()
n=(root/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
checks={
 'native view has no stream-epoch key': 'key: ValueKey(_tvMedia3Epoch)' not in s,
 'epoch passed as reload token': 'reloadToken: _tvMedia3Epoch' in s,
 'URL passed to same view': 'url: _tvMedia3Url' in s,
 'reload token declared': 'final int reloadToken;' in d,
 'reload token default zero': 'this.reloadToken = 0' in d,
 'URL changes trigger reopen': 'oldWidget.url != widget.url' in d,
 'same-URL retries trigger reopen': 'oldWidget.reloadToken != widget.reloadToken' in d,
 'reopen reuses native channel': '_open(widget.url);' in d,
 'native view created only in build': "return AndroidView(" in d,
 'stop still sent for empty URL': "await channel.invokeMethod<void>('stop')" in d,
 'old events still guarded': 'eventGeneration != _nativeGeneration' in d,
 'native owns and releases one playback': 'private val playback = TvMedia3Playback(context)' in n and 'playback.release()' in n,
 'invalid URL clears wait state': "_waitingForOpen = false;\n            widget.onError?.call('INVALID_URL')" in d,
}
for label,passed in checks.items(): print(('PASS' if passed else 'FAIL')+': '+label)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} passed')

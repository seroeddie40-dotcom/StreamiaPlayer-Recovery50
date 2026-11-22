#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
n=(r/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
d=(r/'lib/services/tv_media3_controller.dart').read_text()
checks={
 'native generation stored':'private var streamGeneration = 0L' in n,
 'open increments generation':'streamGeneration++\n                    playback.open(url)' in n,
 'stop increments generation':'"stop" -> {\n                streamGeneration++' in n,
 'lifecycle invalidates generation':n.count('streamGeneration++')>=3 and 'suspendPlaybackForBackground()' in n,
 'native state tagged':'"generation" to streamGeneration' in n,
 'native open acknowledgement':'result.success(streamGeneration)' in n,
 'dart tracks native generation':'int? _nativeGeneration;' in d,
 'dart awaits acknowledgement':'final nativeGeneration = await channel.invokeMethod<int>' in d,
 'dart filters stale messages':'eventGeneration != _nativeGeneration' in d,
 'dart drops interim events':'data is! Map || _waitingForOpen' in d,
 'dart clears on dispose':'_nativeGeneration = null;' in d,
}
for k,v in checks.items():print(('PASS' if v else 'FAIL')+': '+k)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} native event checks passed')

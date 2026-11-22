#!/usr/bin/env python3
from pathlib import Path
screen=(Path(__file__).resolve().parents[1]/'lib/screens/player_screen.dart').read_text()
native=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
checks={
 'Native player stops on activity pause': 'onActivityPaused(activity: Activity)' in native and 'playback.stop()' in native,
 'Resume is gated on background transition': 'final returningFromBackground = !_appInForeground;' in screen,
 'Resume restricted to TV Media3': 'returningFromBackground && _useTvMedia3' in screen,
 'No resume after disposal': '!_playerDisposalStarted && !_playbackRevoked' in screen,
 'No resume without existing stream': '_tvMedia3Url.isNotEmpty && !_streamFailed' in screen,
 'Resume rechecks family authorization': '_isCurrentStreamAuthorized()) {\n        unawaited(_loadStream(reconnect: true));'.replace('\n','\n') in screen,
 'Resumption reuses guarded load path': 'unawaited(_loadStream(reconnect: true));' in screen,
 'Load generation cancels stale stream opens': 'generation != _streamLoadGeneration' in screen,
 'Media3 retains its PlatformView on reload': 'reloadToken: _tvMedia3Epoch' in screen and 'key: ValueKey(_tvMedia3Epoch)' not in screen,
 'Background state marks foreground false': '_appInForeground = false;' in screen,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} passed')

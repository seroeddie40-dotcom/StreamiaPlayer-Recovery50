#!/usr/bin/env python3
"""Static regression contracts for native Android TV channel handoff."""
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt'
s = p.read_text()
checks = {
    'single ExoPlayer instance': s.count('ExoPlayer.Builder(context, renderersFactory)') == 1,
    'switch guard field': 'private var switchingStream = false' in s,
    'suppress old state events': s.count('!released && !switchingStream') >= 3,
    'clear decoder before new media': s.index('exoPlayer.stop()', s.index('fun open(')) < s.index('exoPlayer.setMediaItem(', s.index('fun open(')),
    'clear old media before new media': s.index('exoPlayer.clearMediaItems()', s.index('fun open(')) < s.index('exoPlayer.setMediaItem(', s.index('fun open(')),
    'disable old playWhenReady': 'exoPlayer.playWhenReady = false' in s[s.index('fun open('):s.index('fun stop(')],
    'prepare next media': 'exoPlayer.prepare()' in s,
    'restart new media': 'exoPlayer.playWhenReady = true' in s,
    'finally resets switch guard': s.count('switchingStream = false') >= 3,
    'stop suppresses transient events': 'switchingStream = true' in s[s.index('fun stop('):s.index('fun release(')],
    'release clears surface': 'exoPlayer.clearVideoTextureView(videoView)' in s,
    'main thread enforced': s.count('Looper.myLooper() == Looper.getMainLooper()') >= 3,
}
for name, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ': ' + name)
assert all(checks.values()), 'Native decoder switch contract failed'
print(f'{sum(checks.values())}/{len(checks)} checks passed')

#!/usr/bin/env python3
"""Static checks for the bounded Android-TV Media3 live buffering policy."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt').read_text()
checks={
    'load control imported': 'import androidx.media3.exoplayer.DefaultLoadControl' in s,
    'single bounded policy': s.count('DefaultLoadControl.Builder()') == 1,
    'explicit buffer durations': '.setBufferDurationsMs(' in s,
    'minimum 10 seconds': '10_000, // minBufferMs' in s,
    'maximum 25 seconds': '25_000, // maxBufferMs' in s,
    'start at 1 second': '1_000,  // bufferForPlaybackMs' in s,
    'rebuffer at 2 seconds': '2_000   // bufferForPlaybackAfterRebufferMs' in s,
    'policy attached to player': '.setLoadControl(loadControl)' in s,
    'only one ExoPlayer': s.count('ExoPlayer.Builder(') == 1,
    'decoder fallback retained': '.setEnableDecoderFallback(true)' in s,
    'no extra stream on switch': s.count('exoPlayer.setMediaItem(mediaItemForUrl(url))') == 1,
    'surface release retained': 'exoPlayer.clearVideoTextureView(videoView)' in s,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values()), 'TV buffering policy failed'
print(f'{sum(checks.values())}/{len(checks)} checks passed')

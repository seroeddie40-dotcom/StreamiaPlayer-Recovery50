#!/usr/bin/env python3
"""Static contracts for single-decoder Media3 compatibility fallback."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt').read_text()
checks={
 'explicit renderer factory': 'DefaultRenderersFactory(context)' in s,
 'decoder initialization fallback': '.setEnableDecoderFallback(true)' in s,
 'single player instance': s.count('ExoPlayer.Builder(context, renderersFactory)') == 1,
 'same player for stream switches': 'exoPlayer.setMediaItem(mediaItemForUrl(url))' in s,
 'keep TextureView': 'TextureView(context)' in s and 'exoPlayer.setVideoTextureView(videoView)' in s,
 'opaque video layer': 'isOpaque = true' in s,
 'no forced software decoder': 'MediaCodecSelector' not in s,
 'old media cleared': 'exoPlayer.clearMediaItems()' in s,
 'surface cleared at release': 'exoPlayer.clearVideoTextureView(videoView)' in s,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
assert all(checks.values()), 'Decoder fallback contract failed'
print(f'{sum(checks.values())}/{len(checks)} checks passed')

#!/usr/bin/env python3
"""Static contracts for low-overhead, credential-free native decoder diagnostics."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt').read_text()
checks={
 'Media3 analytics listener': 'exoPlayer.addAnalyticsListener(object : AnalyticsListener' in s,
 'decoder initialization observed': 'override fun onVideoDecoderInitialized(' in s,
 'dropped video frames observed': 'override fun onDroppedVideoFrames(' in s,
 'audio underruns observed': 'override fun onAudioUnderrun(' in s,
 'monotonic health interval': 'SystemClock.elapsedRealtime()' in s,
 'throttled aggregation': 'healthLogIntervalMs = 60_000L' in s and 'reportHealthIfDue()' in s,
 'health reset on stream change': s.count('resetHealthCounters()') >= 3,
 'diagnostics gated on lifecycle': s.count('!released && !switchingStream') >= 3,
 'no stream URLs in logs': 'Log.i("StreamiaMedia3Health", "60s decoder health:' in s and 'Log.i("StreamiaMedia3Health", "Video decoder initialized:' in s,
 'one player instance': s.count('ExoPlayer.Builder(context, renderersFactory)') == 1,
 'no per-frame logging': 'Log.i' not in s[s.index('override fun onDroppedVideoFrames('):s.index('override fun onAudioUnderrun(')],
 'no extra periodic timer': 'Handler(' not in s and 'Timer(' not in s,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} checks passed')

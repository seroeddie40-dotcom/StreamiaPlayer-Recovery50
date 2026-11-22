#!/usr/bin/env python3
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
checks = {
 'tracks host pause': 'private var hostPaused = false' in s,
 'pauses on activity paused': 'override fun onActivityPaused(activity: Activity)' in s and 'if (activity === hostActivity) suspendPlaybackForBackground()' in s and 'if (disposed || hostPaused) return' in s,
 'stops once on pause-stop': s.count('if (activity === hostActivity) suspendPlaybackForBackground()') == 2 and s.count('playback.stop()') == 2,
 'resets on resume': 'override fun onActivityResumed(activity: Activity) {' in s and 'hostPaused = false' in s,
 'rejects stale open': 'if (hostPaused || (hostActivity != null && !hostActivityIsAlive())) {' in s,
 'retains URL validation': 'INVALID_URL' in s,
 'retains one native player': 'private val playback = TvMedia3Playback(context)' in s,
 'cleans lifecycle callbacks': 'application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)' in s,
 'releases native decoder': 'playback.release()' in s,
}
for k, v in checks.items(): print(('PASS' if v else 'FAIL') + ': ' + k)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} native lifecycle checks passed')

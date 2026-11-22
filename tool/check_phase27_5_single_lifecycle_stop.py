#!/usr/bin/env python3
"""Regression guard: pause and stop share one idempotent native suspension."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / "android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt").read_text()
helper = s.split("private fun suspendPlaybackForBackground()", 1)[1].split("private val lifecycleCallbacks", 1)[0]
assert "if (disposed || hostPaused) return" in helper
assert "hostPaused = true" in helper and "streamGeneration++" in helper and "playback.stop()" in helper
for name in ("onActivityPaused", "onActivityStopped"):
    block = s.split(f"override fun {name}", 1)[1].split("override fun ", 1)[0]
    assert "suspendPlaybackForBackground()" in block
assert "hostPaused = false" in s
print("PASS: native pause/stop use one idempotent suspension")

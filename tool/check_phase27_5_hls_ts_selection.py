from pathlib import Path

source = Path(__file__).resolve().parents[1] / "android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt"
code = source.read_text(encoding="utf-8")
checks = {
    "Media3 HLS MIME available": "MimeTypes.APPLICATION_M3U8" in code,
    "Explicit HLS extension": 'path.endsWith(".m3u8")' in code and 'path.endsWith(".m3u")' not in code,
    "Explicit HLS query": '"format", "type", "extension", "ext", "output"' in code,
    "HLS query value": 'value.equals("hls", ignoreCase = true)' in code,
    "TS not forced to HLS": 'builder.setMimeType(MimeTypes.APPLICATION_M3U8)' in code and 'MimeTypes.VIDEO_MP2T' not in code,
    "Reuses player": 'exoPlayer.setMediaItem(mediaItemForUrl(url))' in code,
    "No second player": code.count('ExoPlayer.Builder(') == 1,
    "No extra timer": 'Timer(' not in code,
    "Retains decoder fallback": '.setEnableDecoderFallback(true)' in code,
}
for label, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {label}")
assert all(checks.values())
print(f"{len(checks)}/{len(checks)} checks passed")

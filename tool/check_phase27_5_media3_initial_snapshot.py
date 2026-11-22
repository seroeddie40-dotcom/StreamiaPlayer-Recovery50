from pathlib import Path
root = Path(__file__).resolve().parents[1]
view = (root / 'lib/services/tv_media3_controller.dart').read_text()
platform = (root / 'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
playback = (root / 'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3Playback.kt').read_text()
checks = {
    'snapshot method': '"snapshot" -> {' in platform,
    'native snapshot generation': '"generation" to streamGeneration' in platform,
    'read only playback snapshot': 'fun playbackSnapshot(): Pair<Int, Boolean>' in playback,
    'snapshot reads state': 'exoPlayer.playbackState, exoPlayer.isPlaying' in playback,
    'flutter requests snapshot': "'snapshot'" in view,
    'flutter checks current generation': '_nativeGeneration == nativeGeneration' in view,
    'flutter checks native generation': "snapshot['generation'] == nativeGeneration" in view,
    'flutter checks widget mounted': 'mounted && generation == _generation' in view,
    'flutter accepts state': 'widget.onState?.call(state, playing)' in view,
    'snapshot optional for older native': 'catch (_)' in view,
}
for name, ok in checks.items():
    assert ok, name
print(f"PASS {len(checks)}/{len(checks)} media3 initial snapshot checks")

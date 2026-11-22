from pathlib import Path

root = Path(__file__).resolve().parents[1]
controller = (root / "lib/services/tv_media3_controller.dart").read_text()
screen = (root / "lib/screens/player_screen.dart").read_text()
native = (root / "android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt").read_text()
assert "if (e.code != 'APP_BACKGROUND')" in controller
assert "widget.onError?.call(e.code);" in controller
assert 'returningFromBackground && _useTvMedia3' in screen
assert "_loadStream(reconnect: true)" in screen
assert 'result.error("APP_BACKGROUND"' in native
print('Background-open race static checks passed')

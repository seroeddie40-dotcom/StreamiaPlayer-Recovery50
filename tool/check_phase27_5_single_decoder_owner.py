from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt'
s = p.read_text()
assert 'var activeOwner: TvMedia3PlatformView? = null' in s
assert 'if (activeOwner !== this) activeOwner?.relinquishDecoder()' in s
assert s.index('activeOwner?.relinquishDecoder()') < s.index('playback.open(url)')
assert 'if (activeOwner === this) activeOwner = null' in s
assert '"stop" -> {\n                relinquishDecoder()' in s
print('TV single decoder owner source contract: PASS')

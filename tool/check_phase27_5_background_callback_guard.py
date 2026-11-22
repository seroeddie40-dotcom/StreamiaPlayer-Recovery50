from pathlib import Path

screen = (Path(__file__).resolve().parents[1] / "lib/screens/player_screen.dart").read_text()
for signature in (
    "void _onTvMedia3State(int state, bool playing) {",
    "void _onTvMedia3Error(String code) {",
):
    section = screen.split(signature, 1)[1].split("\n  }", 1)[0]
    assert "!_appInForeground || _playbackRevoked" in section
    assert "_tvMedia3Url.isEmpty" in section
assert "returningFromBackground && _useTvMedia3" in screen
print("Background native callback guards passed")

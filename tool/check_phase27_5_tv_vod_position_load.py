#!/usr/bin/env python3
from pathlib import Path
p=(Path(__file__).resolve().parents[1]/'lib/screens/player_screen.dart').read_text()
segment=p.split('_posSub = _player.stream.position.listen((p) {',1)[1].split('_durSub =',1)[0]
checks={
  'Live TV retains no rebuild position path': 'DeviceLayout.isTelevision && widget.isLive' in segment and '_position = p;' in segment,
  'TV VOD has dedicated throttled path': 'DeviceLayout.isTelevision && !widget.isLive' in segment,
  'TV VOD retains precise playback position': '_position = p;' in segment,
  'TV VOD compares displayed seconds': 'second != _lastTvVodRenderedSecond' in segment,
  'TV VOD only redraws while overlay visible': 'if (_showControls || _showHistory || _showDrawer) setState(() {});' in segment,
  'Mobile position update preserved': 'setState(() => _position = p);' in segment,
  'No new player/decoder created': 'Player(' not in segment and 'TvMedia3View(' not in segment,
  'TV VOD redraw state declared': 'int _lastTvVodRenderedSecond = -1;' in p,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')

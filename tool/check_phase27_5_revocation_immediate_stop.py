#!/usr/bin/env python3
"""Regression guard: both revocation entry points request TV stop immediately."""
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'lib/screens/player_screen.dart'
s = p.read_text(encoding='utf-8')
load = s.split('Future<void> _loadStream(', 1)[1].split('final url = _currentUrl;', 1)[0]
family = s.split('void _onFamilySessionChanged()', 1)[1].split('bool _canPlayChannel(', 1)[0]
for name, section in [('load', load), ('family', family)]:
    assert 'if (_useTvMedia3 && mounted)' in section, name
    assert "_tvMedia3Url = ''; ++_tvMedia3Epoch;" in section, name
    assert section.index("_tvMedia3Url = ''; ++_tvMedia3Epoch;") < section.index('await previousOpen.catchError'), name
assert 'if (!_playerDisposalStarted && !_useTvMedia3)' in load
print('PASS: revoked TV playback requests stop before waiting for Dart queue')

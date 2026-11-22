#!/usr/bin/env python3
from pathlib import Path
p = (Path(__file__).resolve().parents[1] / 'lib/screens/player_screen.dart').read_text()
section = p.split('KeyEventResult _handleRemoteKey(',1)[1].split('void _focusFirstPlayerAction()',1)[0]
checks = {
 'OK handles select and enter': 'LogicalKeyboardKey.select' in section and 'LogicalKeyboardKey.enter' in section,
 'Focused child control retains OK': '_showControls && !_playerSurfaceFocus.hasPrimaryFocus' in section,
 'Live TV opens/toggles controls': '_toggleLiveControls();' in section,
 'VOD OK shows controls': 'if (!_showControls) setState(() => _showControls = true);' in section,
 'VOD OK moves focus to controls': '_focusFirstPlayerAction();' in section,
 'VOD OK does not toggle playback': '_player.pause()' not in section and '_player.play()' not in section,
 'Back hides controls before route pop': p.index('if (_showControls) {\n          _hideTimer?.cancel();') < p.index('Navigator.of(context).pop();'),
 'Back restores surface focus': '_restorePlayerFocus();' in p,
 'No new player instance in remote handler': 'Player(' not in section,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')

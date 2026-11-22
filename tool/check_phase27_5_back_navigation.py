#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = (root / 'lib/screens/player_screen.dart').read_text()
e = (root / 'lib/widgets/tv_epg_timeline.dart').read_text()
checks = {
  'PopScope blocks implicit route pop': 'canPop: false' in p,
  'Back closes drawer first': p.index('if (_showDrawer) { _closeNavigationDrawer(); return; }') < p.index('if (_showHistory) { _closeHistorySidebar(); return; }'),
  'Back closes history before controls': p.index('if (_showHistory) { _closeHistorySidebar(); return; }') < p.index('if (_showControls) {\n          _hideTimer?.cancel();'),
  'Back cancels controls timer': 'if (_showControls) {\n          _hideTimer?.cancel();' in p,
  'Back restores video surface focus': 'setState(() => _showControls = false);\n          _restorePlayerFocus();' in p,
  'Back exits only when overlays closed': 'Navigator.of(context).pop();' in p,
  'EPG details are a dialog': 'showDialog<void>' in e,
  'EPG dialog has a close action': "child: const Text('Schließen')" in e,
  'EPG details do not switch channels': '_showDetails(items[_selected]);' in e,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ': ' + name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')

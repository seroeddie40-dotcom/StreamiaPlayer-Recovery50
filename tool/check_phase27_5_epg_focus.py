"""Source-level regression contracts; not a substitute for Flutter widget tests."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
epg = (root / 'lib/widgets/tv_epg_timeline.dart').read_text()
live = (root / 'lib/screens/live_tv_screen.dart').read_text()
checks = {
    'epg-row-state': 'int _selectedRow = 0;' in epg,
    'epg-adjacent-row': 'final targetRow = _selectedRow +' in epg,
    'epg-spanning-row-advance': '_selectedRow = targetRow;' in epg,
    'epg-selected-row-highlight': '_selectedRow == row' in epg,
    'epg-touch-row': '_selectedRow = row;' in epg,
    'epg-edge-focus-release': 'return KeyEventResult.ignored;' in epg,
    'epg-focus-listener-disposal': '_focus.removeListener(_onFocusChanged)' in epg,
    'category-clears-stale-epg': '_tvEpgKey = null;' in live and '_tvEpgFuture = null;' in live,
    'preview-no-decoder': 'no second decoder or stream' in live,
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if not all(checks.values()):
    raise SystemExit(1)
print(f'{len(checks)}/{len(checks)} source checks passed')

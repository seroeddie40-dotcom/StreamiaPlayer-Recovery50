from pathlib import Path
root=Path(__file__).resolve().parents[1]
tv=(root/'lib/widgets/tv_epg_timeline.dart').read_text()
live=(root/'lib/screens/live_tv_screen.dart').read_text()
checks={
  'EPG handles keyboard only on key-down': 'event is! KeyDownEvent' in tv,
  'EPG releases focus at left/right edges': 'next < 0 || next >= items.length) return KeyEventResult.ignored' in tv,
  'EPG releases focus at top/bottom edges': 'targetRow < 0 || targetRow >= 4) return KeyEventResult.ignored' in tv,
  'EPG handles updated programme lists': 'void didUpdateWidget' in tv,
  'EPG guards stale selected index': 'if (_selected >= items.length)' in tv,
  'EPG has traversal group': 'FocusTraversalGroup(child: Focus(' in tv,
  'Categories grouped for traversal': 'FocusTraversalGroup(child: _categoryPanel' in live,
  'Channels grouped for traversal': 'FocusTraversalGroup(child: _tvChannelList' in live,
  'Preview grouped for traversal': 'FocusTraversalGroup(child: _tvPreview' in live,
  'Channel access rechecked on opening': 'family.canAccessCategory(' in live,
  'EPG preview uses cached future': 'future: _tvEpgFuture' in live,
}
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL')+' '+name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} checks passed')

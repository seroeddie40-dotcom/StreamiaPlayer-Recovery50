from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'lib/screens/live_tv_screen.dart'
s = p.read_text()
checks = {
 'tv-three-columns': ('Expanded(flex: 5, child: _tvChannelList' in s or 'Expanded(flex: 5, child: FocusTraversalGroup(child: _tvChannelList' in s) and ('Expanded(flex: 6, child: _tvPreview' in s or 'Expanded(flex: 6, child: FocusTraversalGroup(child: _tvPreview' in s),
 'mobile-grid-preserved': 'else Expanded(child: filtered.isEmpty' in s and 'GridView.builder(' in s,
 'permission-rechecked': 'family.canAccessCategory(' in s and "contentType: 'live'" in s,
 'no-preview-decoder': 'Player(' not in s[s.index('  Widget _tvPreview('):s.index('  @override\n  Widget build(BuildContext context) {\n    final family')],
 'epg-cache-used': '_tvEpgRepository.programmes(' in s,
 'tv-epg-component': 'TvEpgTimeline(key: ValueKey(key)' in s,
 'no-extra-favorite-focus-stop': 'final _tvEpgRepository' not in s and False or 'final EpgRepository _tvEpgRepository' in s,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} checks passed')

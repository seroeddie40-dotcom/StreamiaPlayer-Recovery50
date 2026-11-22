#!/usr/bin/env python3
"""Source-contract checks only: not a Flutter build or device test."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
favorites = (root/'lib/screens/favorites_library_screen.dart').read_text()
player = (root/'lib/screens/player_screen.dart').read_text()
tv = (root/'lib/widgets/tv_epg_timeline.dart').read_text()
checks = {
  'favorite-first-match-live': 'if (item.id == id) return allowed(item.categoryKey);' in favorites,
  'favorite-no-any-bypass': 'i.id == id && allowed(i.categoryKey)' not in favorites,
  'favorite-open-check': 'family.canAccessCategory(' in favorites,
  'player-family-listener': '_familySession.addListener(_onFamilySessionChanged)' in player,
  'player-epg-integration': 'ChannelEpgPanel(programmes: snapshot.data!)' in player,
  'player-epg-cache': '_epgRepository.programmes(url, channelId)' in player,
  'tv-epg-four-rows': 'List.generate(4' in tv,
  'tv-epg-three-hours': 'Duration(hours: row * 3)' in tv,
  'tv-epg-edge-not-trapped': 'next < 0 || next >= items.length) return KeyEventResult.ignored' in tv,
  'tv-epg-details': '_showDetails(items[_selected])' in tv,
  'tv-epg-no-second-decoder': 'Player(' not in tv and 'VideoController(' not in tv,
}
for name, success in checks.items(): print(('PASS' if success else 'FAIL')+' '+name)
print(f'{sum(checks.values())}/{len(checks)} source checks passed')
raise SystemExit(0 if all(checks.values()) else 1)

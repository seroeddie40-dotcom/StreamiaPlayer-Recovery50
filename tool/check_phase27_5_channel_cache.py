#!/usr/bin/env python3
from pathlib import Path
p=(Path(__file__).resolve().parents[1]/'lib/screens/player_screen.dart').read_text()
checks={
 'Authorized channel cache declared': 'List<Channel>? _allowedLiveChannelCache;' in p,
 'Cache checks list identity': 'identical(source, _allowedLiveChannelSource)' in p,
 'Cache checks source key': 'library.sourceKey == _allowedLiveChannelSourceKey' in p,
 'Cache denies before readiness': 'if (!family.isReady) return const <Channel>[];' in p,
 'Cache uses original permission predicate': 'source.where(_canPlayChannel).toList(growable: false)' in p,
 'Family changes invalidate before authorization': '_onFamilySessionChanged() {\n    _invalidateAllowedLiveChannels();\n    if (!mounted' in p,
 'Zapping reuses authorized list': 'final allowed = _allowedLiveChannels();' in p,
 'Drawer reuses authorized list': 'final channels = _allowedLiveChannels();' in p,
 'Drawer listens to family changes': 'context.watch<FamilySessionProvider>();' in p,
 'Drawer listens to content changes': 'context.watch<ContentProvider>();' in p,
}
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} passed')

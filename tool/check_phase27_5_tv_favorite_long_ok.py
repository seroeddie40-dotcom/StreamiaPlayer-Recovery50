from pathlib import Path
p=Path(__file__).resolve().parents[1]/'lib/screens/live_tv_screen.dart'
s=p.read_text()
checks={
 'long-ok-handler': 'onLongPress: () => _toggleTvFavorite(channel, sourceKey)' in s,
 'permission-before-toggle': "family.canAccessCategory(sourceKey: sourceKey," in s,
 'profile-current-guard': 'family.activeProfile?.id == profileId' in s,
 'source-current-guard': 'context.read<ContentProvider>().sourceKey == sourceKey' in s,
 'outbox-enqueue': 'await ProfileFavoriteOutbox.enqueue(user.id, profileId, sourceKey,' in s,
 'outbox-flush': 'await ProfileFavoriteOutbox.flush(client, user.id, profileId,' in s,
 'favorites-revision': 'favoritesRevision.value++' in s,
 'existing-focus-restore': 'pushWithFocusRestore(context,' in s,
 'no-per-row-toggle-widget': '_tvChannelList' in s and 'onLongPress: () => _toggleTvFavorite' in s,
}
for name,ok in checks.items():print(('PASS' if ok else 'FAIL'),name)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} static checks passed')

from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'lib/screens/live_tv_screen.dart').read_text()
checks={
 'stable per-entry focus nodes': 'final Map<Channel, FocusNode> _tvChannelFocusNodes' in s,
 'focus assigned to TV row': 'focusNode: _focusFor(channel)' in s,
 'restore after player return': '_restoreTvChannelFocus(channel, sourceKey)' in s,
 'route still current': "ModalRoute.of(context)?.isCurrent != true" in s,
 'permission snapshot ready': 'if (!family.isReady || content.sourceKey != sourceKey)' in s,
 'fresh permitted catalogue': '_permittedChannels(content.channels, family, sourceKey)' in s,
 'filtered entry verified': 'filtered.contains(channel) ? channel' in s,
 'no focus if empty': 'if (target == null) return;' in s,
 'focus nodes disposed': 'for (final node in _tvChannelFocusNodes.values) { node.dispose(); }' in s,
 'invalid preview cleared': 'if (_tvSelectedChannel != null && !filtered.contains(_tvSelectedChannel))' in s,
 'category invalidates return': '_tvReturnChannel = null;' in s,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL'), name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} source contracts passed')

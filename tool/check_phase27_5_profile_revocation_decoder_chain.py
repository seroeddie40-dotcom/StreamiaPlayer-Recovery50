from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'lib/screens/player_screen.dart').read_text()
w=(root/'lib/services/tv_media3_controller.dart').read_text()
k=(root/'android/app/src/main/kotlin/com/streamia/streamia_player/TvMedia3PlatformView.kt').read_text()
# Ownership bound at route opening, even if a replacement profile can access the same title.
assert '_openingProfileId = _familySession.activeProfile?.id;' in p
assert '_openingAccountId = _familySession.activeProfile?.accountUserId;' in p
assert 'current.id == _openingProfileId' in p and 'current.accountUserId == _openingAccountId' in p
assert 'if (_belongsToOpeningProfile && _isCurrentStreamAuthorized()) return;' in p
assert 'bool permitted = family.isReady && _belongsToOpeningProfile;' in p
# Revocation invalidates retry and queued opens before issuing native stop.
r=p.split('  void _onFamilySessionChanged() {',1)[1].split('  bool _canPlayChannel(',1)[0]
for token in ('_playbackRevoked = true;', '++_streamLoadGeneration;', '_reconnectTimer?.cancel();', '_stallMonitor?.cancel();', "_tvMedia3Url = '';", '++_tvMedia3Epoch;', 'await previousOpen.catchError', 'await _player.stop();'):
    assert token in r, token
assert r.index('++_streamLoadGeneration;') < r.index("_tvMedia3Url = ''")
assert r.index("_tvMedia3Url = ''") < r.index('await previousOpen.catchError')
# Prevent manual/background/timer retries from reopening revoked stream.
assert 'if (!mounted || _playerDisposalStarted || _playbackRevoked ||' in p
assert 'final permitted = !_playbackRevoked && _isCurrentStreamAuthorized();' in p
assert 'generation != _streamLoadGeneration' in p
assert 'oldWidget.url != widget.url' in w
assert "await channel.invokeMethod<void>('stop');" in w
assert 'if (activeOwner === this) activeOwner = null' in k
assert 'playback.stop()' in k
assert 'if (activeOwner !== this) activeOwner?.relinquishDecoder()' in k
print('PASS: profile switch -> revoke -> cancel retries/opens -> native stop -> decoder owner release (static contract)')

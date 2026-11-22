"""Guard against deadlocking the playback queue on family permission revocation."""
from pathlib import Path
s = Path('lib/screens/player_screen.dart').read_text()
start = s.index('  void _onFamilySessionChanged() {')
end = s.index('  bool _canPlayChannel(', start)
block = s[start:end]
assert 'final revocation = Completer<void>();' in block
assert '_openQueue = revocation.future;' in block
assert 'finally {' in block and 'revocation.complete();' in block
assert block.index('revocation.complete();') > block.index('finally {')
assert 'await previousOpen.catchError' in block
assert '_playbackRevoked = true;' in block
print('PASS: family revocation releases the serialized playback queue')

load = s[s.index('  Future<void> _loadStream('):s.index('  void _onTvMedia3State(', s.index('  Future<void> _loadStream('))]
denied = load[load.index('    if (!permitted) {'):load.index('    final url = _currentUrl;')]
assert denied.index('_playbackRevoked = true;') < denied.index('await previousOpen.catchError')
assert '_reconnectTimer?.cancel();' in denied
assert '_stallMonitor?.cancel();' in denied
print('PASS: denied opens invalidate playback and pending retries before queued stop')

from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'lib/screens/player_screen.dart').read_text()
series = s.split('bool _canPlaySeries(Series item)', 1)[1].split('void _switchEpisode(', 1)[0]
switch = s.split('void _switchEpisode(int nextIndex', 1)[1].split('bool _canOpenRecent(', 1)[0]
drawer = s.split('Widget _buildEpisodesDrawer()', 1)[1].split('Future<void> _toggleRecording()', 1)[0]
current = s.split('bool _isCurrentStreamAuthorized()', 1)[1].split('Future<void> _loadStream(', 1)[0]
assert 'matches.every((candidate)' in series
assert 'candidate.seasons' not in series and 'episode.streamUrl' not in series
assert 'await ' not in switch and 'unawaited(_saveProgress())' in switch
assert 'setState(()' in switch and 'unawaited(_loadStream())' in switch
assert 'onTap: () => _switchEpisode(i, closeDrawer: true)' in drawer
assert 'await _saveProgress()' not in drawer and '_canPlaySeries(' not in drawer
assert "_canPlaySeries(widget.series!)" in current
assert "episodeUrl:" not in s
assert '_familySession.addListener(_onFamilySessionChanged)' in s
assert '_contentProvider.addListener(_onFamilySessionChanged)' in s
assert 'if (_belongsToOpeningProfile && _isCurrentStreamAuthorized()) return;' in s
print('PASS: all episode controls switch instantly, series/folder permission once, revoke listener retained')

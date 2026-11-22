from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'lib/screens/player_screen.dart').read_text()
checks={
 'idle timeout declared':'_tvMedia3IdleTimeout = Duration(seconds: 25)' in s,
 'idle timestamp declared':'DateTime? _tvMedia3IdleSince;' in s,
 'idle watchdog before reconnect skip':s.index('if (_useTvMedia3 && _tvMedia3IdleSince != null)') < s.index('if (_reconnecting) return;'),
 'idle timeout bounded':"_tvDiagnostics.failure('media3-idle-timeout');" in s,
 'uses existing retry':"_tvDiagnostics.failure('media3-idle-timeout');\n        _handlePlaybackFailure();" in s,
 'idle clock set once':'_tvMedia3IdleSince ??= DateTime.now();' in s,
 'non-idle resets clock': 'if (state == 1) {' in s and 'else {\n      _tvMedia3IdleSince = null;\n    }' in s,
 'startup retry resets idle': '_bufferingStartedAt = null;\n    _tvMedia3AwaitingFirstStateAt = null;\n    _tvMedia3IdleSince = null;' in s,
 'no extra timer':s.count('Timer.periodic(const Duration(seconds: 5)') == 1,
 'existing startup watchdog kept':'_tvMedia3StartupTimeout = Duration(seconds: 30)' in s,
}
for name,ok in checks.items():print(('PASS' if ok else 'FAIL')+' '+name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')

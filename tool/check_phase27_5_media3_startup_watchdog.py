from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'lib/screens/player_screen.dart').read_text()
checks = {
    'startup timeout constant': '_tvMedia3StartupTimeout = Duration(seconds: 30)' in s,
    'clock declared': 'DateTime? _tvMedia3AwaitingFirstStateAt;' in s,
    'clock armed on native view request': '_tvMedia3AwaitingFirstStateAt = DateTime.now();\n          setState' in s,
    'watchdog before reconnect skip': s.index('if (_useTvMedia3 && _tvMedia3AwaitingFirstStateAt != null)') < s.index('if (_reconnecting) return;'),
    'timeout invokes existing failure path': "_tvDiagnostics.failure('media3-startup-timeout');\n        _handlePlaybackFailure();" in s,
    'first native state cancels': '_tvMedia3AwaitingFirstStateAt = null;\n    // Media3 Player.STATE_BUFFERING' in s,
    'native error cancels': '_tvMedia3AwaitingFirstStateAt = null;\n    // Native side forwards' in s,
    'background cancels': '_appInForeground = false;\n      _tvMedia3AwaitingFirstStateAt = null;' in s,
    'revocation cancels': 'if (!permitted) {' in s and s.index('_tvMedia3AwaitingFirstStateAt = null;', s.index('if (!permitted) {')) < s.index('await previousOpen.catchError', s.index('if (!permitted) {')),
    'no additional timer': 'Timer.periodic(const Duration(seconds: 5)' in s,
}
for label, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + label)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')

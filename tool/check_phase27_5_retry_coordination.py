from pathlib import Path
s = (Path(__file__).resolve().parents[1] / "lib/screens/player_screen.dart").read_text()
checks = {
    "retry generation guard": "generation != _streamLoadGeneration" in s,
    "retry failure guard": "!_streamFailed || !_appInForeground" in s,
    "retry permission guard": "!_isCurrentStreamAuthorized()) return;\n      _reconnectTimer = null;" in s,
    "retry timer cleared before opening": "_reconnectTimer = null;\n      unawaited(_loadStream(reconnect: true));" in s,
    "recovery cancels pending retry": "if (playing) {\n      _reconnectTimer?.cancel();" in s,
    "recovery clears timer reference": "_reconnectTimer = null;\n      _tvMedia3IdleSince = null;" in s,
    "startup watchdog retained": "_tvMedia3StartupTimeout" in s,
    "idle watchdog retained": "_tvMedia3IdleTimeout" in s,
    "buffer watchdog retained": "_bufferingTimeout" in s,
    "bounded retries retained": "_maxAutomaticReconnects = 2" in s,
}
for name, ok in checks.items():
    assert ok, name
print(f"PASS {len(checks)}/{len(checks)} retry coordination checks")

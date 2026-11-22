"""Static safeguards for queued native Media3 channel switches."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'lib/services/tv_media3_controller.dart').read_text()
checks = {
    'single native request queue': 'Future<void> _openQueue = Future<void>.value();',
    'immediate generation advance': 'final generation = ++_generation;',
    'invalidate old event generation': '_nativeGeneration = null;',
    'ignore old events while switching': '_waitingForOpen = url.isNotEmpty;',
    'serialized operation': '_openQueue = _openQueue.then((_) async {',
    'skip superseded request': 'if (!mounted || generation != _generation) return;',
    'native call in queued operation': 'await _performOpen(url, generation);',
    'queue recovers after failure': '}).catchError((Object _) {',
    'stop is serialized': "await channel.invokeMethod<void>('stop');",
    'open is serialized': "'open', <String, Object>{'url': url}",
    'native generation reconciliation': '_nativeGeneration = nativeGeneration;',
    'snapshot guard remains': '!_stateDeliveredForGeneration && snapshot != null',
    'dispose invalidates requests': 'void dispose() {\n    ++_generation;',
}
for name, needle in checks.items():
    assert needle in s, f'FAILED: {name}'
print(f'OK: {len(checks)} checks – Media3 switch serialization')

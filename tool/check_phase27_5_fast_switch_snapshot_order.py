from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'lib/services/tv_media3_controller.dart').read_text()
checks = {
    'snapshot state guard': '!_stateDeliveredForGeneration && snapshot != null' in s,
    'generation guard': '_nativeGeneration == nativeGeneration' in s,
    'snapshot marks delivery': '_stateDeliveredForGeneration = true;\n                  widget.onState?.call(state, playing);' in s,
    'native event marks delivery': '_stateDeliveredForGeneration = true;\n          widget.onState?.call(state, playing);' in s,
    'reset on open': '_stateDeliveredForGeneration = false;\n    _waitingForOpen = url.isNotEmpty;' in s,
    'reset on dispose': '_stateDeliveredForGeneration = false;\n    _waitingForOpen = false;\n    final channel' in s,
    'event generation check': 'eventGeneration != _nativeGeneration' in s,
    'no added timers': 'Timer(' not in s,
}
for k,v in checks.items():
    assert v, k
print(f'PASS {len(checks)}/{len(checks)} fast-switch snapshot ordering checks')

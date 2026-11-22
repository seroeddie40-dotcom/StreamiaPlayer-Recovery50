#!/usr/bin/env python3
"""Static contract: terminal Media3 format/transport errors do not churn decoders."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'lib/screens/player_screen.dart').read_text()
checks={
 'failure handler defaults to retry': 'void _handlePlaybackFailure({bool allowAutomaticRetry = true})' in s,
 'retry suppression before increment': 'if (!allowAutomaticRetry ||\n        _automaticReconnects >= _maxAutomaticReconnects) return;' in s,
 'unsupported video codec terminal': "'ERROR_CODE_DECODING_FORMAT_UNSUPPORTED'" in s,
 'unsupported container terminal': "'ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED'" in s,
 'unsupported manifest terminal': "'ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED'" in s,
 'cleartext restriction terminal': "'ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED'" in s,
 'only exact native codes classified': 'nonRecoverableCodes.contains(code)' in s,
 'no logging of source URL': "_tvDiagnostics.failure('media3-error')" in s,
 'manual retry preserved': 'void _retryPlaybackManually()' in s,
 'native callback forwards error code': '_onTvMedia3Error(String code)' in s,
}
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} checks passed')

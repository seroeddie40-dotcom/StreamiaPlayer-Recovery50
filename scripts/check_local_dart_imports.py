
#!/usr/bin/env python3
"""Catch broken relative Dart imports before the expensive Flutter setup.

This checks file existence only; Flutter analyze remains authoritative.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
errors = []
checked = 0
for folder in ('lib', 'test'):
    for source in (ROOT / folder).rglob('*.dart'):
        code = source.read_text(encoding='utf-8')
        for match in re.finditer(r"^\s*(?:import|export|part)\s+['\"](\.{1,2}/[^'\"]+)['\"]", code, re.MULTILINE):
            checked += 1
            relative = match.group(1)
            destination = (source.parent / relative).resolve()
            if not destination.is_relative_to(ROOT.resolve()) or not destination.is_file():
                errors.append(f'{source.relative_to(ROOT)}: missing {relative}')
if errors:
    for error in errors:
        print('FAIL:', error)
    raise SystemExit(1)
print(f'PASS: {checked} local Dart import/export/part references resolve')

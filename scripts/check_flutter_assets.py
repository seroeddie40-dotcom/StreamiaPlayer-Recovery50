
#!/usr/bin/env python3
"""Offline validation of Flutter asset declarations and eight language files.

This check does not replace flutter pub get, flutter analyze, or a device test.
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
manifest = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
errors = []

# Match the indented Flutter assets section, without requiring PyYAML in CI.
match = re.search(r'^flutter:\s*\n(?P<body>(?:^[ \t]+.*\n|^\s*\n)*)', manifest, re.M)
if not match:
    errors.append('Missing flutter: section in pubspec.yaml')
else:
    body = match.group('body')
    assets = re.search(r'^  assets:\s*\n(?P<items>(?:^    - .*\n)*)', body, re.M)
    if not assets:
        errors.append('Missing Flutter assets list')
    else:
        for item in re.findall(r'^    -\s+(.+?)\s*$', assets.group('items'), re.M):
            rel = item.strip("'\"")
            path = ROOT / rel
            if not path.exists():
                errors.append(f'Flutter asset path does not exist: {rel}')
            elif path.is_dir() and not any(p.is_file() for p in path.rglob('*')):
                errors.append(f'Flutter asset directory is empty: {rel}')

languages = ('de', 'tr', 'en', 'ru', 'pl', 'es', 'fr', 'ar')
reference_keys = None
for lang in languages:
    path = ROOT / 'assets' / 'lang' / f'{lang}.json'
    if not path.is_file():
        errors.append(f'Missing language file: {path.relative_to(ROOT)}')
        continue
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (UnicodeError, json.JSONDecodeError) as exc:
        errors.append(f'Invalid language JSON {lang}: {exc}')
        continue
    if not isinstance(data, dict):
        errors.append(f'Language JSON must be an object: {lang}')
        continue
    keys = set(data)
    if reference_keys is None:
        reference_keys = keys
    elif keys != reference_keys:
        errors.append(f'Language keys differ for {lang}: missing={sorted(reference_keys-keys)}, extra={sorted(keys-reference_keys)}')

if errors:
    for error in errors:
        print('FAIL:', error)
    sys.exit(1)
print(f'PASS: Flutter assets and {len(languages)} language JSON files ({len(reference_keys or ())} shared keys)')

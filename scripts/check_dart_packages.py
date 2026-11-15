
#!/usr/bin/env python3
"""Check direct Dart package imports against declared pubspec dependencies."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
section = None
declared = set()
for line in pubspec.splitlines():
    top = re.match(r'^([A-Za-z_][\w-]*):\s*(?:#.*)?$', line)
    if top:
        section = top.group(1)
        continue
    if section in {'dependencies', 'dev_dependencies'}:
        item = re.match(r'^  ([A-Za-z_][\w-]*):(?:\s|$)', line)
        if item:
            declared.add(item.group(1))
project = re.search(r'^name:\s*([\w-]+)', pubspec, re.M)
if project:
    declared.add(project.group(1))

errors = []
checked = 0
for folder in ('lib', 'test', 'integration_test', 'tool'):
    directory = root / folder
    if not directory.is_dir():
        continue
    for path in directory.rglob('*.dart'):
        source = path.read_text(encoding='utf-8')
        for package in re.findall(r"(?:import|export)\s+['\"]package:([A-Za-z_]\w*)/", source):
            checked += 1
            if package not in declared:
                errors.append(f'{path.relative_to(root)}: undeclared package {package}')
if errors:
    for error in errors:
        print('FAIL:', error)
    raise SystemExit(1)
print(f'PASS: {checked} package imports checked; {len(declared)} declared packages')

#!/usr/bin/env python3
"""Report compressed APK component sizes without modifying packages."""
import sys
from collections import Counter
from pathlib import Path
from zipfile import ZipFile

for argument in sys.argv[1:]:
    path = Path(argument)
    if not path.is_file():
        print(f'{path.name}: not built')
        continue
    groups = Counter()
    with ZipFile(path) as apk:
        for item in apk.infolist():
            parts = item.filename.split('/')
            group = '/'.join(parts[:2]) if parts[0] == 'lib' else parts[0]
            groups[group] += item.compress_size
    print(f'\n{path.name}: {path.stat().st_size / 1048576:.2f} MiB on disk')
    for group, size in groups.most_common():
        print(f'{group:40} {size / 1048576:8.2f} MiB compressed')

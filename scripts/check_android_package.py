#!/usr/bin/env python3
"""Offline structural checks; does not replace Flutter/Gradle builds."""
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
manifest=root/'android/app/src/main/AndroidManifest.xml'
node=ET.parse(manifest).getroot()
android='{http://schemas.android.com/apk/res/android}'
app=node.find('application')
assert app is not None and app.attrib.get(android+'banner')=='@drawable/tv_banner'
activity=app.find('activity')
assert activity is not None
assert any(c.attrib.get(android+'name')=='android.intent.category.LEANBACK_LAUNCHER' for c in activity.findall('./intent-filter/category'))
ET.parse(root/'android/app/src/debug/AndroidManifest.xml')
assert (root/'android/app/src/main/res/drawable/tv_banner.png').is_file()
assert not (root/'android/app/src/debug/AndroidManifest').exists()
assert 'signingConfigs.getByName("debug")' not in (root/'android/app/build.gradle.kts').read_text()
print('Android package structural checks: OK (not a compile test)')

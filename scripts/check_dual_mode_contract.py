#!/usr/bin/env python3
"""Source-level checks for the Streamia Android TV / mobile startup contract.

This is not a substitute for flutter analyze, tests, or device testing.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
errors = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

layout = (ROOT / 'lib/core/platform/device_layout.dart').read_text(encoding='utf-8')
main = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
app = (ROOT / 'lib/app.dart').read_text(encoding='utf-8')
android = (ROOT / 'android/app/src/main/kotlin/com/streamia/streamia_player/MainActivity.kt').read_text(encoding='utf-8')

require("MethodChannel('com.streamia/device_identity')" in layout, 'Dart device channel missing')
require('"com.streamia/device_identity"' in android, 'Kotlin device channel missing')
require("invokeMethod<bool>('isTelevision')" in layout, 'Dart TV method missing')
require('"isTelevision" ->' in android, 'Kotlin TV method missing')
require('UiModeManager' in android and 'FEATURE_LEANBACK' in android, 'Native TV signals missing')
require('UI_MODE_TYPE_TELEVISION' in android, 'TV mode type check missing')
require('leanback_only' in android, 'Leanback-only TV box detection missing')
require('result.success(isTv)' in android, 'Native TV detection result not returned')
require('await DeviceLayout.initialize()' in main, 'TV detection not awaited')
require('await SystemChrome.setPreferredOrientations(' in main, 'Initial orientation missing')
require(0 <= main.find('runApp(') < main.find('await DeviceLayout.initialize()') < main.find('await SystemChrome.setPreferredOrientations('), 'Render bootstrap before device detection and orientation')
require(0 <= main.find('await SystemChrome.setPreferredOrientations(') < main.find('await Supabase.initialize('), 'Initial orientation must precede Supabase network initialization')
require('DeviceLayout.isTelevision' in main, 'Orientation not device-specific')
require('DeviceOrientation.landscapeLeft' in main and 'DeviceOrientation.landscapeRight' in main, 'TV landscape orientation missing')
require('DeviceOrientation.portraitUp' in main, 'Mobile portrait orientation missing')
# Startup orientation remains device-specific in main.dart. A phone-only
# route transition may subsequently change orientation at the dashboard.
require('class _LandscapeDashboardState' in app, 'Dashboard orientation lifecycle missing')
require('if (DeviceLayout.isTelevision) return;' in app, 'Dashboard orientation must not affect Android TV')
require('DeviceOrientation.landscapeLeft' in app and 'DeviceOrientation.landscapeRight' in app,
        'Dashboard landscape orientations missing')
require('DeviceOrientation.portraitUp' in app, 'Return-to-onboarding portrait missing')
require('SystemChrome.setPreferredOrientations(orientations)' in app,
        'Dashboard orientation transition missing')
require('_applyOrientation(landscape: true)' in app and '_applyOrientation(landscape: false)' in app,
        'Dashboard orientation enter/exit handling missing')

require('kIsWeb' in layout, 'Web platform guard missing')
require('MissingPluginException' in layout and 'PlatformException' in layout, 'Native channel failure handling missing')

for dart in (ROOT / 'lib').rglob('*.dart'):
    code = dart.read_text(encoding='utf-8')
    require(not re.search(r'\bDeviceLayout\.isTv\b', code), f'Legacy isTv reference: {dart.relative_to(ROOT)}')

if errors:
    for error in errors:
        print('FAIL:', error)
    raise SystemExit(1)
print('PASS: Android TV/mobile startup source contract')

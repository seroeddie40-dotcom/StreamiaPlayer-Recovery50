
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('focus restoration is TV-only and checks parent route', () {
    final source = File('lib/core/focus_navigation.dart').readAsStringSync();
    expect(source.contains('if (!DeviceLayout.isTelevision)'), isTrue);
    expect(source.contains('parentRoute?.isCurrent != true'), isTrue);
    expect(source.contains('Scrollable.ensureVisible('), isTrue);
  });

  test('error and playlist focus are TV-only', () {
    final recent = File('lib/screens/continue_watching_screen.dart').readAsStringSync();
    final admin = File('lib/screens/admin_devices_screen.dart').readAsStringSync();
    final playlists = File('lib/screens/playlist_management_screen.dart').readAsStringSync();
    expect(recent.contains('autofocus: DeviceLayout.isTelevision'), isTrue);
    expect(admin.contains('autofocus: DeviceLayout.isTelevision'), isTrue);
    expect(playlists.contains('autofocus: DeviceLayout.isTelevision &&'), isTrue);
  });

  test('focus fallback stays in the originating focus scope', () {
    final source = File('lib/core/focus_navigation.dart').readAsStringSync();
    expect(source.contains('previousScope.traversalDescendants'), isTrue);
    expect(source.contains('validInOriginalScope(candidate)'), isTrue);
    expect(source.contains('ModalRoute.of(nodeContext) == parentRoute'), isTrue);
    expect(source.contains('previousScope.nextFocus()'), isFalse);
  });

  test('native and Flutter TV detection method names agree', () {
    final dart = File('lib/core/platform/device_layout.dart').readAsStringSync();
    final kotlin = File('android/app/src/main/kotlin/com/streamia/streamia_player/MainActivity.kt').readAsStringSync();
    expect(dart.contains("invokeMethod<bool>('isTelevision')"), isTrue);
    expect(kotlin.contains('"isTelevision" ->'), isTrue);
  });

  test('parental PIN and folder controls only request initial TV focus', () {
    final source = File('lib/screens/parental_lock_screen.dart').readAsStringSync();
    expect(source.contains("import '../core/platform/device_layout.dart';"), isTrue);

    expect(
      RegExp(
        r'autofocus:\s*DeviceLayout\.isTelevision\s*&&\s*row\s*==\s*0\s*&&\s*column\s*==\s*0',
      ).allMatches(source).length,
      1,
    );

    expect(
      RegExp(
        r'autofocus:\s*DeviceLayout\.isTelevision\s*&&\s*index\s*==\s*0',
      ).allMatches(source).length,
      1,
    );

    expect(source.contains('autofocus: i == 0,'), isFalse);
  });

  test('language selection shows a distinct TV remote focus', () {
    final source = File('lib/screens/language_selection_screen.dart').readAsStringSync();
    expect(source.contains('onFocusChange: (focused)'), isTrue);
    expect(source.contains('_focusedLanguage == languageCode'), isTrue);
    expect(source.contains('languageCode == selectedLanguage'), isTrue);
  });

  test('TV always uses traditional focus highlighting', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source.contains('FocusHighlightStrategy.alwaysTraditional'), isTrue);
  });

  test('startup detects TV before choosing the device orientation', () {
    final source = File('lib/main.dart').readAsStringSync();
    final detection = source.indexOf('await DeviceLayout.initialize();');
    final orientation = source.indexOf('await SystemChrome.setPreferredOrientations(');
    final appStart = source.indexOf('runApp(');
    expect(detection, greaterThanOrEqualTo(0));
    expect(orientation, greaterThan(detection));
    expect(appStart, greaterThan(orientation));
    expect(source.contains('DeviceLayout.isTelevision'), isTrue);
  });
}

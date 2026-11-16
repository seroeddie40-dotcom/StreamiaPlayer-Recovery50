import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recordings list, play and delete require an adult family session', () {
    final source = File('lib/screens/recordings_screen.dart').readAsStringSync();
    expect(source.contains('final family = context.watch<FamilySessionProvider>();'), isTrue);
    expect(source.contains('Future<void> _play(_RecordingEntry entry) async {\n    final family = context.read<FamilySessionProvider>();\n    if (!family.isReady || !family.isAdult) return;'), isTrue);
    expect(source.contains('Future<void> _delete(_RecordingEntry entry) async {\n    final family = context.read<FamilySessionProvider>();\n    if (!family.isReady || !family.isAdult) return;'), isTrue);
  });

  test('recording playback stops when adult authorization is revoked', () {
    final source = File('lib/screens/recordings_screen.dart').readAsStringSync();
    expect(source.contains('_familySession.addListener(_onFamilyChanged);'), isTrue);
    expect(source.contains('_familySession.removeListener(_onFamilyChanged);'), isTrue);
    expect(source.contains('if (!_familySession.isReady || !_familySession.isAdult) {\n      _player.pause();'), isTrue);
  });
}

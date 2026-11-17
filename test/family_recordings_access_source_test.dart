import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/recording_service.dart';

void main() {
  test('recording ownership separates accounts and profiles', () {
    final owner = RecordingService.ownerKey('account', 'child');
    final filename = 'sp_${owner}_channel.ts';
    expect(RecordingService.ownsName(filename, owner), isTrue);
    expect(RecordingService.ownsName(filename, RecordingService.ownerKey('account', 'adult')), isFalse);
    expect(RecordingService.ownsName(filename, RecordingService.ownerKey('other', 'child')), isFalse);
    expect(RecordingService.ownsName('legacy.ts', owner), isFalse);
  });
  test('recording screen filters both storage locations and revokes playback', () {
    final source = File('lib/screens/recordings_screen.dart').readAsStringSync();
    expect(source, contains('RecordingService.ownsName(entity.uri.pathSegments.last, owner)'));
    expect(source, contains('RecordingService.ownsName(name, owner)'));
    expect(source, contains('if (confirmed != true || !mounted || !_owns(entry)) return;'));
    expect(source, contains('_recordingOwner(_familySession) != widget.ownerKey'));
    expect(source, contains('_player.stop();'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/playlist_refresh_schedule.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);
  test('legacy repair detects fully uncategorized catalogs only', () {
    expect(PlaylistRefreshSchedule.needsLegacyRepair([]), isFalse);
    expect(PlaylistRefreshSchedule.needsLegacyRepair([null, ' ']), isTrue);
    expect(PlaylistRefreshSchedule.needsLegacyRepair([null, '42']), isFalse);
  });
  test('automatic retries wait fifteen minutes per attempt', () {
    expect(PlaylistRefreshSchedule.retryAllowed(now, null), isTrue);
    expect(PlaylistRefreshSchedule.retryAllowed(now, now.subtract(const Duration(minutes: 14))), isFalse);
    expect(PlaylistRefreshSchedule.retryAllowed(now, now.subtract(const Duration(minutes: 15))), isTrue);
    expect(PlaylistRefreshSchedule.retryAllowed(now, now.add(const Duration(hours: 1))), isTrue);
  });
  test('disabled schedule never runs', () {
    expect(PlaylistRefreshSchedule.isDue(hours: 0, now: now), isFalse);
  });
  test('new schedule is due', () {
    expect(PlaylistRefreshSchedule.isDue(hours: 6, now: now), isTrue);
  });
  test('six hour boundary', () {
    expect(PlaylistRefreshSchedule.isDue(hours: 6, now: now,
      lastSuccess: now.subtract(const Duration(hours: 5, minutes: 59))), isFalse);
    expect(PlaylistRefreshSchedule.isDue(hours: 6, now: now,
      lastSuccess: now.subtract(const Duration(hours: 6))), isTrue);
  });
}

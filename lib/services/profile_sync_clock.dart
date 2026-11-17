import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses monotonic elapsed time after a successful server sample.
/// Before calibration the device clock is only a best-effort fallback.
class ProfileSyncClock {
  static DateTime? _anchor;
  static Stopwatch? _elapsed;

  static DateTime now() => _anchor?.add(_elapsed!.elapsed) ?? DateTime.now().toUtc();

  static Future<void> calibrate(SupabaseClient client) async {
    final trip = Stopwatch()..start();
    try {
      final result = await client.rpc('profile_sync_server_time').timeout(const Duration(seconds: 3));
      final server = DateTime.parse(result as String).toUtc();
      if (trip.elapsed > const Duration(seconds: 3)) return;
      _anchor = server.add(Duration(microseconds: trip.elapsedMicroseconds ~/ 2));
      _elapsed = Stopwatch()..start();
    } catch (_) {
      // Retain last successful calibration during connection loss.
    }
  }
}

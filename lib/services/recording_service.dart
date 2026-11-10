import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RecordingService {
  static IOSink? _sink;
  static bool _active = false;

  static bool get isActive => _active;

  static Future<bool> start(String channelName) async {
    if (_active) return true;
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/recordings');
      if (!await recDir.exists()) await recDir.create(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = channelName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
      final file = File('${recDir.path}/${safeName}_$ts.ts');
      _sink = file.openWrite();
      _active = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _active = false;
  }
}

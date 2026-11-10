import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/playlist_source_config.dart';

/// Keeps source URLs and Xtream credentials in the platform secure storage,
/// separate from playlist display metadata in SharedPreferences.
class PlaylistSourceStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _prefix = 'streamia_source_v1_';

  Future<void> save(PlaylistSourceConfig config) async {
    await _storage.write(
      key: '$_prefix${config.sourceKey}',
      value: jsonEncode(config.toJson()),
    );
  }

  Future<PlaylistSourceConfig?> read(String sourceKey) async {
    final raw = await _storage.read(key: '$_prefix$sourceKey');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PlaylistSourceConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String sourceKey) => _storage.delete(key: '$_prefix$sourceKey');
}

import 'profile_sync_clock.dart';
import 'dart:convert';
import 'profile_favorite_outbox.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile-based favorites sync and portable, versioned JSON backup.
/// No playlist credentials, stream URLs, or media files are exported.
class FavoritesBackupService {
  FavoritesBackupService(this._client, {required this.profileId, required this.isCurrent, required this.parentToken});
  final String profileId;
  final String? Function() parentToken;
  final bool Function() isCurrent;
  final SupabaseClient _client;
  static const int schemaVersion = 1;

  String get _userId {
    if (!isCurrent()) throw StateError('Profile session changed');
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Bitte zuerst anmelden.');
    return id;
  }

  Future<List<Map<String, dynamic>>> loadAll() async {
    return ProfileFavoriteOutbox.load(_client,_userId,profileId,parentToken(),isCurrent);

  }

  Future<void> add({
    required String contentId,
    required String contentType,
    required String title,
    required String sourceKey,
    String? sourceLabel,
  }) async {
    if (!{'live', 'vod', 'series'}.contains(contentType)) {
      throw ArgumentError.value(contentType, 'contentType');
    }
    final account = _userId;
    await ProfileFavoriteOutbox.enqueue(account, profileId, sourceKey,
        contentType, contentId, title, sourceLabel ?? '', true);
    await _flush(account);
  }

  Future<void> remove({
    required String contentId,
    required String contentType,
    required String sourceKey,
  }) async {
    final account = _userId;
    await ProfileFavoriteOutbox.enqueue(account, profileId, sourceKey,
        contentType, contentId, '', '', false);
    await _flush(account);
  }

  Future<void> _flush(String account) async {
    if (!isCurrent() || _client.auth.currentUser?.id != account) return;
    final token = parentToken();
    await ProfileFavoriteOutbox.flush(_client, account, profileId, token,
        () => isCurrent() && _client.auth.currentUser?.id == account && parentToken() == token);
  }

  Future<void> exportBackup({String? onlyType}) async {
    final all = await loadAll();
    if (!isCurrent()) throw StateError('Profile session changed');
    final selected = onlyType == null
        ? all
        : all.where((r) => r['content_type'] == onlyType).toList();
    final backup = <String, dynamic>{
      'format': 'streamia_favorites_backup',
      'schema_version': schemaVersion,
      'exported_at': ProfileSyncClock.now().toIso8601String(),
      'categories': ['live', 'vod', 'series'],
      'favorites': selected.map((r) => {
        'content_id': r['content_id'],
        'content_type': r['content_type'],
        'title': r['title'],
        'source_key': r['source_key'],
        'source_label': r['source_label'],
      }).toList(),
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
    final suffix = onlyType == null ? 'all' : onlyType;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Streamia-Favoriten sichern',
      fileName: 'streamia_favorites_$suffix.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    // A null path means the user cancelled the save dialog; cancellation is not an error.
    if (path == null) return;
  }

  Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return 0;
    final bytes = result.files.single.bytes;
    if (bytes == null) throw FormatException('Die Backup-Datei konnte nicht gelesen werden.');
    if (bytes.length > 10 * 1024 * 1024) {
      throw FormatException('Die Backup-Datei ist größer als 10 MB.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['format'] != 'streamia_favorites_backup') {
      throw FormatException('Das ist keine gültige Streamia-Favoriten-Sicherung.');
    }
    if (decoded['schema_version'] != schemaVersion || decoded['favorites'] is! List) {
      throw FormatException('Diese Backup-Version wird nicht unterstützt.');
    }
    final rawFavorites = decoded['favorites'] as List;
    if (rawFavorites.length > 50000) {
      throw FormatException('Das Backup enthält mehr als 50.000 Einträge.');
    }
    final records = <Map<String, dynamic>>[];
    for (final item in rawFavorites) {
      if (item is! Map) continue;
      final type = item['content_type']?.toString();
      final id = item['content_id']?.toString();
      final source = item['source_key']?.toString();
      final title = item['title']?.toString();
      if (!{'live', 'vod', 'series'}.contains(type) || id == null || id.isEmpty ||
          source == null || source.isEmpty || source.length > 500 ||
          title == null || title.trim().isEmpty || title.length > 1000 || id.length > 500) continue;
      records.add({
        'user_id': _userId,
      'family_profile_id': profileId,
        
        'content_id': id,
        'content_type': type,
        'title': title,
        'source_key': source,
        'source_label': item['source_label']?.toString(),
        'updated_at': ProfileSyncClock.now().toIso8601String(),
      });
    }
    // Deduplicate within the backup too: Postgres cannot update the same conflict row twice in one statement.
    final unique = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final key = jsonEncode([record['content_type'], record['source_key'], record['content_id']]);
      unique[key] = record;
    }
    final cleanRecords = unique.values.toList();
    final account = _userId;
    for (final record in cleanRecords) {
      if (!isCurrent() || _client.auth.currentUser?.id != account) {
        throw StateError('Profile session changed');
      }
      await ProfileFavoriteOutbox.enqueue(account, profileId,
          record['source_key'] as String, record['content_type'] as String,
          record['content_id'] as String, record['title'] as String,
          record['source_label']?.toString() ?? '', true);
    }
    await _flush(account);
    return cleanRecords.length;
  }
}

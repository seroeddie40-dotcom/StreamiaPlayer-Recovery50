import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';

class StoredIptvLibrary {
  final List<Channel> channels;
  final List<VodItem> vod;
  final List<Series> series;
  const StoredIptvLibrary({required this.channels, required this.vod, required this.series});
}

/// AES-256-GCM encrypted per-playlist catalog. Encryption key lives in secure storage.
/// Deleting Android app data or losing the secure key makes this cache unreadable.
class IptvLibraryDatabase {
  IptvLibraryDatabase._();
  static final IptvLibraryDatabase instance = IptvLibraryDatabase._();
  Database? _database;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyName = 'streamia_catalog_aes256_key_v2';
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _cachedKey;

  Future<SecretKey> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    var encoded = await _secureStorage.read(key: _keyName);
    if (encoded == null) {
      final fresh = await _cipher.newSecretKey();
      final bytes = await fresh.extractBytes();
      encoded = base64Encode(bytes);
      await _secureStorage.write(key: _keyName, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw StateError('Invalid catalog encryption key');
    return _cachedKey = SecretKey(bytes);
  }

  Future<String> _encrypt(Map<String, Object?> payload) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)), secretKey: await _getKey(),
    );
    return base64Encode(<int>[...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Map<String, dynamic>> _decrypt(String encoded) async {
    final bytes = base64Decode(encoded);
    if (bytes.length < 28) throw const FormatException('Invalid encrypted catalog row');
    final box = SecretBox(
      bytes.sublist(12, bytes.length - 16),
      nonce: bytes.sublist(0, 12),
      mac: Mac(bytes.sublist(bytes.length - 16)),
    );
    final plaintext = await _cipher.decrypt(box, secretKey: await _getKey());
    return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
  }

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = '${await getDatabasesPath()}/streamia_library_secure_v2.db';
    return _database = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE libraries (source_key TEXT PRIMARY KEY, updated_at TEXT NOT NULL)');
      for (final table in ['channels', 'vod', 'series']) {
        await db.execute('CREATE TABLE $table (source_key TEXT NOT NULL, item_id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(source_key, item_id))');
      }
      await db.execute('CREATE INDEX idx_channels_source ON channels(source_key)');
      await db.execute('CREATE INDEX idx_vod_source ON vod(source_key)');
      await db.execute('CREATE INDEX idx_series_source ON series(source_key)');
    });
  }

  Future<bool> contains(String sourceKey) async {
    final rows = await (await _db).query('libraries', columns: ['source_key'], where: 'source_key = ?', whereArgs: [sourceKey], limit: 1);
    return rows.isNotEmpty;
  }

  /// Atomically replaces one playlist. The previous catalog survives any failed write.
  /// onProgress counts rows queued within the transaction, not network download bytes.
  Future<void> replace({
    required String sourceKey,
    required List<Channel> channels,
    required List<VodItem> vod,
    required List<Series> series,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (sourceKey.trim().isEmpty) throw ArgumentError('sourceKey must not be empty');
    final db = await _db;
    // Encrypt before opening the transaction. No stream URL is written as plaintext.
    final encryptedChannels = <Map<String, Object?>>[];
    final encryptedVod = <Map<String, Object?>>[];
    final encryptedSeries = <Map<String, Object?>>[];
    for (final item in channels) {
      encryptedChannels.add({'source_key': sourceKey, 'item_id': item.id,
        'payload': await _encrypt(_channelToJson(item))});
    }
    for (final item in vod) {
      encryptedVod.add({'source_key': sourceKey, 'item_id': item.id,
        'payload': await _encrypt(_vodToJson(item))});
    }
    for (final item in series) {
      encryptedSeries.add({'source_key': sourceKey, 'item_id': item.id,
        'payload': await _encrypt(_seriesToJson(item))});
    }
    final total = channels.length + vod.length + series.length;
    var completed = 0;
    await db.transaction((txn) async {
      for (final table in ['channels', 'vod', 'series']) {
        await txn.delete(table, where: 'source_key = ?', whereArgs: [sourceKey]);
      }
      Future<void> insertRows(String table, Iterable<Map<String, Object?>> rows) async {
        var batch = txn.batch();
        var pending = 0;
        for (final row in rows) {
          batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
          pending++;
          if (pending == 400) {
            await batch.commit(noResult: true);
            completed += pending;
            onProgress?.call(completed, total);
            batch = txn.batch();
            pending = 0;
          }
        }
        if (pending > 0) {
          await batch.commit(noResult: true);
          completed += pending;
          onProgress?.call(completed, total);
        }
      }
      await insertRows('channels', encryptedChannels);
      await insertRows('vod', encryptedVod);
      await insertRows('series', encryptedSeries);
      await txn.insert('libraries', {
        'source_key': sourceKey, 'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    onProgress?.call(total, total);
  }

  Future<StoredIptvLibrary?> load(String sourceKey) async {
    final db = await _db;
    if (!await contains(sourceKey)) return null;
    Future<List<dynamic>> read(String table) async {
      final rows = await db.query(table, columns: ['payload'], where: 'source_key = ?', whereArgs: [sourceKey]);
      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        result.add(await _decrypt(row['payload'] as String));
      }
      return result;
    }
    return StoredIptvLibrary(
      channels: (await read('channels')).map((v) => _channelFromJson(v as Map<String, dynamic>)).toList(growable: false),
      vod: (await read('vod')).map((v) => _vodFromJson(v as Map<String, dynamic>)).toList(growable: false),
      series: (await read('series')).map((v) => _seriesFromJson(v as Map<String, dynamic>)).toList(growable: false),
    );
  }

  Future<void> delete(String sourceKey) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in ['channels', 'vod', 'series']) {
        await txn.delete(table, where: 'source_key = ?', whereArgs: [sourceKey]);
      }
      await txn.delete('libraries', where: 'source_key = ?', whereArgs: [sourceKey]);
    });
  }

  Map<String, Object?> _channelToJson(Channel c) => {
    'id': c.id, 'name': c.name, 'streamUrl': c.streamUrl,
    'logoUrl': c.logoUrl, 'category': c.category, 'epgChannelId': c.epgChannelId,
  };
  Channel _channelFromJson(Map<String, dynamic> j) => Channel(
    id: j['id'] as String, name: j['name'] as String, streamUrl: j['streamUrl'] as String,
    logoUrl: j['logoUrl'] as String?, category: j['category'] as String?, epgChannelId: j['epgChannelId'] as String?,
  );

  Map<String, Object?> _vodToJson(VodItem v) => {
    'id': v.id, 'title': v.title, 'plot': v.plot, 'posterUrl': v.posterUrl,
    'backdropUrl': v.backdropUrl, 'genre': v.genre, 'releaseDate': v.releaseDate,
    'ageRating': v.ageRating, 'director': v.director, 'cast': v.cast,
    'rating': v.rating, 'externalMetadataId': v.externalMetadataId,
    'metadataSource': v.metadataSource, 'metadataProviderId': v.metadataProviderId,
    'metadataAttribution': v.metadataAttribution, 'metadataLicense': v.metadataLicense,
    'metadataSourceUrl': v.metadataSourceUrl, 'streamUrl': v.streamUrl,
    'durationSeconds': v.durationSeconds,
  };
  VodItem _vodFromJson(Map<String, dynamic> j) => VodItem(
    id: j['id'] as String, title: j['title'] as String,
    plot: j['plot'] as String?, posterUrl: j['posterUrl'] as String?, backdropUrl: j['backdropUrl'] as String?,
    genre: j['genre'] as String?, releaseDate: j['releaseDate'] as String?, ageRating: j['ageRating'] as String?,
    director: j['director'] as String?, cast: j['cast'] as String?, rating: (j['rating'] as num?)?.toDouble(),
    externalMetadataId: j['externalMetadataId'] as String?, metadataSource: j['metadataSource'] as String?,
    metadataProviderId: j['metadataProviderId'] as String?, metadataAttribution: j['metadataAttribution'] as String?,
    metadataLicense: j['metadataLicense'] as String?, metadataSourceUrl: j['metadataSourceUrl'] as String?,
    streamUrl: j['streamUrl'] as String, durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
  );

  Map<String, Object?> _seriesToJson(Series s) => {
    'id': s.id, 'title': s.title, 'plot': s.plot, 'posterUrl': s.posterUrl,
    'backdropUrl': s.backdropUrl, 'genre': s.genre, 'releaseDate': s.releaseDate,
    'ageRating': s.ageRating, 'cast': s.cast, 'director': s.director,
    'rating': s.rating, 'externalMetadataId': s.externalMetadataId,
    'metadataSource': s.metadataSource, 'metadataProviderId': s.metadataProviderId,
    'metadataAttribution': s.metadataAttribution, 'metadataLicense': s.metadataLicense,
    'metadataSourceUrl': s.metadataSourceUrl,
    'seasons': s.seasons.map((season) => {
      'number': season.number,
      'episodes': season.episodes.map((e) => {
        'id': e.id, 'title': e.title, 'number': e.number, 'plot': e.plot,
        'stillUrl': e.stillUrl, 'releaseDate': e.releaseDate, 'streamUrl': e.streamUrl,
        'durationSeconds': e.durationSeconds, 'metadataProviderId': e.metadataProviderId,
        'metadataAttribution': e.metadataAttribution, 'metadataLicense': e.metadataLicense,
        'metadataSourceUrl': e.metadataSourceUrl,
      }).toList(),
    }).toList(),
  };
  Series _seriesFromJson(Map<String, dynamic> j) => Series(
    id: j['id'] as String, title: j['title'] as String,
    plot: j['plot'] as String?, posterUrl: j['posterUrl'] as String?, backdropUrl: j['backdropUrl'] as String?,
    genre: j['genre'] as String?, releaseDate: j['releaseDate'] as String?, ageRating: j['ageRating'] as String?,
    cast: j['cast'] as String?, director: j['director'] as String?, rating: (j['rating'] as num?)?.toDouble(),
    externalMetadataId: j['externalMetadataId'] as String?, metadataSource: j['metadataSource'] as String?,
    metadataProviderId: j['metadataProviderId'] as String?, metadataAttribution: j['metadataAttribution'] as String?,
    metadataLicense: j['metadataLicense'] as String?, metadataSourceUrl: j['metadataSourceUrl'] as String?,
    seasons: ((j['seasons'] as List?) ?? []).map((rawSeason) {
      final season = rawSeason as Map<String, dynamic>;
      return Season(
        number: (season['number'] as num).toInt(),
        episodes: ((season['episodes'] as List?) ?? []).map((rawEpisode) {
          final e = rawEpisode as Map<String, dynamic>;
          return Episode(
            id: e['id'] as String, title: e['title'] as String, number: (e['number'] as num).toInt(),
            plot: e['plot'] as String?, stillUrl: e['stillUrl'] as String?, releaseDate: e['releaseDate'] as String?,
            streamUrl: e['streamUrl'] as String, durationSeconds: (e['durationSeconds'] as num?)?.toInt(),
            metadataProviderId: e['metadataProviderId'] as String?, metadataAttribution: e['metadataAttribution'] as String?,
            metadataLicense: e['metadataLicense'] as String?, metadataSourceUrl: e['metadataSourceUrl'] as String?,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false),
  );
}

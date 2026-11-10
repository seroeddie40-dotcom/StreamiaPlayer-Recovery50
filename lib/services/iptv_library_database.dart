import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';

class StoredIptvLibrary {
  final List<Channel> channels;
  final List<VodItem> vod;
  final List<Series> series;
  const StoredIptvLibrary({required this.channels, required this.vod, required this.series});
}

/// Persistent, per-playlist catalog. Credentials remain in PlaylistSourceStore.
class IptvLibraryDatabase {
  IptvLibraryDatabase._();
  static final IptvLibraryDatabase instance = IptvLibraryDatabase._();
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = '${await getDatabasesPath()}/streamia_library_v1.db';
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
      await insertRows('channels', channels.map((c) => {
        'source_key': sourceKey, 'item_id': c.id, 'payload': jsonEncode(_channelToJson(c)),
      }));
      await insertRows('vod', vod.map((v) => {
        'source_key': sourceKey, 'item_id': v.id, 'payload': jsonEncode(_vodToJson(v)),
      }));
      await insertRows('series', series.map((s) => {
        'source_key': sourceKey, 'item_id': s.id, 'payload': jsonEncode(_seriesToJson(s)),
      }));
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
      return rows.map((row) => jsonDecode(row['payload'] as String)).toList();
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

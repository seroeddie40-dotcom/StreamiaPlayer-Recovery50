import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent, app-local download queue. Paused/resumable HTTP transfers are
/// intentionally not advertised: an interrupted transfer must be restarted.
enum DownloadState { queued, downloading, completed, cancelled, failed, interrupted, missing }

class DownloadEntry {
  final String id;
  final String title;
  final String kind; // movie or episode
  final String? seriesTitle;
  final int? season;
  final int? episode;
  final String sourceUrl;
  final String filename;
  final DownloadState state;
  final double progress;
  final String? error;

  const DownloadEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.sourceUrl,
    required this.filename,
    required this.state,
    this.seriesTitle,
    this.season,
    this.episode,
    this.progress = 0,
    this.error,
  });

  DownloadEntry copyWith({DownloadState? state, double? progress, String? error}) =>
      DownloadEntry(
        id: id, title: title, kind: kind, sourceUrl: sourceUrl,
        filename: filename, state: state ?? this.state,
        seriesTitle: seriesTitle, season: season, episode: episode,
        progress: progress ?? this.progress, error: error,
      );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'kind': kind, 'sourceUrl': sourceUrl,
    'filename': filename, 'state': state.name, 'progress': progress,
    'seriesTitle': seriesTitle, 'season': season, 'episode': episode,
    'error': error,
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    id: json['id'] as String, title: json['title'] as String,
    kind: json['kind'] as String, sourceUrl: json['sourceUrl'] as String,
    filename: json['filename'] as String,
    state: DownloadState.values.firstWhere(
      (s) => s.name == json['state'], orElse: () => DownloadState.failed,
    ),
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    seriesTitle: json['seriesTitle'] as String?,
    season: (json['season'] as num?)?.toInt(),
    episode: (json['episode'] as num?)?.toInt(),
    error: json['error'] as String?,
  );
}

class DownloadService {
  static final Dio _dio = Dio();
  static final ValueNotifier<List<DownloadEntry>> entries =
      ValueNotifier<List<DownloadEntry>>(const []);
  static final Map<String, CancelToken> _tokens = {};
  static final Set<String> _removing = {};
  static final Map<String, Completer<void>> _activeOperations = {};
  static Future<void>? _initialization;
  static Future<void> _pendingSave = Future<void>.value();

  static Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/downloads');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> initialize() =>
      _initialization ??= _load().catchError((Object error) {
        _initialization = null;
        throw error;
      });

  static Future<void> _load() async {
    final dir = await _directory();
    final index = File('${dir.path}/downloads.json');
    if (!await index.exists()) return;
    final decoded = jsonDecode(await index.readAsString()) as List<dynamic>;
    final result = <DownloadEntry>[];
    for (final value in decoded) {
      try {
        var entry = DownloadEntry.fromJson(Map<String, dynamic>.from(value as Map));
        if (entry.state == DownloadState.queued ||
            entry.state == DownloadState.downloading) {
          entry = entry.copyWith(state: DownloadState.interrupted);
        } else if (entry.state == DownloadState.completed &&
            !await File('${dir.path}/${entry.filename}').exists()) {
          entry = entry.copyWith(state: DownloadState.missing);
        }
        result.add(entry);
      } catch (_) {
        // A corrupt item must not hide all other saved downloads.
      }
    }
    entries.value = List.unmodifiable(result);
    await _save();
  }

  static Future<void> _save() {
    final snapshot = entries.value.map((e) => e.toJson()).toList();
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final dir = await _directory();
      final temp = File('${dir.path}/downloads.json.tmp');
      await temp.writeAsString(jsonEncode(snapshot), flush: true);
      final target = File('${dir.path}/downloads.json');
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
    });
    return _pendingSave;
  }

  static void _put(DownloadEntry entry) {
    if (_removing.contains(entry.id)) return;
    final updated = [...entries.value];
    final index = updated.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      updated.add(entry);
    } else {
      updated[index] = entry;
    }
    entries.value = List.unmodifiable(updated);
  }

  static String _safeName(String value) {
    final clean = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return clean.length > 80 ? clean.substring(0, 80) : clean;
  }

  // Preserve a recognized media extension. Saving every stream as .mp4 can
  // misidentify MPEG-TS and Matroska files during offline playback.
  static String _extensionFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final extension in const ['.mp4', '.mkv', '.ts', '.mov', '.m4v', '.webm']) {
      if (path.endsWith(extension)) return extension;
    }
    return '.mp4';
  }

  // A stable suffix avoids collisions between IDs that sanitize to the same
  // filename (for example a/b and a_b). No external package is required.
  static String _idSuffix(String id) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(id)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<File?> start({
    required String id,
    required String title,
    required String kind,
    required String url,
    String? seriesTitle,
    int? season,
    int? episode,
  }) async {
    await initialize();
    if (_tokens.containsKey(id) || _removing.contains(id)) return null;
    // Never overwrite a valid offline copy when a screen retries the same ID.
    final previous = entries.value.where((entry) => entry.id == id);
    if (previous.isNotEmpty && previous.first.state == DownloadState.completed) {
      final dir = await _directory();
      final existing = File('${dir.path}/${previous.first.filename}');
      if (await existing.exists()) return existing;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      throw ArgumentError.value(url, 'url', 'Invalid download URL');
    }
    final dir = await _directory();
    final filename = '${_safeName(title)}_${_safeName(id)}_${_idSuffix(id)}${_extensionFor(url)}';
    final output = File('${dir.path}/$filename');
    final part = File('${output.path}.part');
    final token = CancelToken();
    _tokens[id] = token;
    final operation = Completer<void>();
    _activeOperations[id] = operation;
    _put(DownloadEntry(id: id, title: title, kind: kind, sourceUrl: url,
      filename: filename, state: DownloadState.queued, seriesTitle: seriesTitle,
      season: season, episode: episode));
    try {
      await _save();
      if (token.isCancelled) {
        final current = entries.value.where((e) => e.id == id);
        if (current.isNotEmpty) {
          _put(current.first.copyWith(state: DownloadState.cancelled));
          await _save();
        }
        return null;
      }
      if (await part.exists()) await part.delete();
      final current = entries.value.firstWhere((e) => e.id == id);
      _put(current.copyWith(state: DownloadState.downloading));
      await _save();
      await _dio.download(url, part.path, cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total <= 0 || token.isCancelled || _removing.contains(id)) return;
          final item = entries.value.where((e) => e.id == id);
          if (item.isEmpty) return;
          _put(item.first.copyWith(progress: received / total));
        });
      if (token.isCancelled || _removing.contains(id)) {
        if (!_removing.contains(id)) {
          final current = entries.value.where((e) => e.id == id);
          if (current.isNotEmpty) {
            _put(current.first.copyWith(state: DownloadState.cancelled));
            await _save();
          }
        }
        return null;
      }
      if (await output.exists()) await output.delete();
      await part.rename(output.path);
      final item = entries.value.firstWhere((e) => e.id == id);
      _put(item.copyWith(state: DownloadState.completed, progress: 1));
      await _save();
      return output;
    } catch (error) {
      if (!_removing.contains(id)) {
        final item = entries.value.where((e) => e.id == id);
        if (item.isNotEmpty) {
          _put(item.first.copyWith(
            state: (error is DioException && CancelToken.isCancel(error)) || token.isCancelled
                ? DownloadState.cancelled : DownloadState.failed,
            error: error.toString(),
          ));
          await _save();
        }
      }
      if (!(error is DioException && CancelToken.isCancel(error))) rethrow;
      return null;
    } finally {
      // Release the waiting remover even if deleting the temporary file fails.
      try {
        if (await part.exists()) await part.delete();
      } finally {
        _tokens.remove(id);
        _activeOperations.remove(id);
        if (!operation.isCompleted) operation.complete();
      }
    }
  }

  static void cancel(String id) => _tokens[id]?.cancel('Cancelled by user');

  /// Cancel the transfer first, wait for Dio to release its file handle, then
  /// delete the completed/partial file and its catalog entry. This avoids a
  /// cancelled transfer recreating a file after the user has deleted it.
  static Future<void> remove(String id) async {
    await initialize();
    if (!_removing.add(id)) return;
    try {
      cancel(id);
      final active = _activeOperations[id];
      if (active != null) await active.future;
      final matches = entries.value.where((e) => e.id == id).toList();
      final dir = await _directory();
      for (final item in matches) {
        for (final path in [
          '${dir.path}/${item.filename}',
          '${dir.path}/${item.filename}.part',
        ]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
      entries.value = List.unmodifiable(entries.value.where((e) => e.id != id));
      await _save();
    } finally {
      _removing.remove(id);
    }
  }

  /// Compatibility API used by older screens until their migration is complete.
  static Future<File> download({
    required String url,
    required String filename,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _directory();
    final safeFilename = _safeName(filename);
    final path = '${dir.path}/$safeFilename';
    await _dio.download(url, path,
      onReceiveProgress: onProgress, cancelToken: cancelToken);
    return File(path);
  }
}

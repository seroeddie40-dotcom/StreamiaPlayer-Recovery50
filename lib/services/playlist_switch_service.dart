import 'playlist_refresh_schedule.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist_profile.dart';
import '../providers/content_provider.dart';
import 'playlist_parser.dart';
import 'playlist_profile_store.dart';
import 'playlist_source_store.dart';
import 'xtream_service.dart';

/// Reloads a previously configured remote playlist without exposing secrets
/// to the profile metadata store.
class PlaylistSwitchService {
  static final Set<String> _refreshingSources = <String>{};
  final PlaylistSourceStore _sources;
  final PlaylistProfileStore _profiles;

  PlaylistSwitchService({PlaylistSourceStore? sources, PlaylistProfileStore? profiles})
      : _sources = sources ?? PlaylistSourceStore(),
        _profiles = profiles ?? PlaylistProfileStore();

  Future<bool> refresh(PlaylistProfile profile, ContentProvider content, {bool Function()? mayPublish, bool repair = false}) async {
    if (!_refreshingSources.add(profile.sourceKey)) return false;
    RandomAccessFile? handle;
    var locked = false;
    try {
      final directory = await getApplicationSupportDirectory();
      final locks = Directory('${directory.path}/playlist_refresh_locks');
      await locks.create(recursive: true);
      final digest = sha256.convert(utf8.encode(profile.sourceKey));
      handle = await File('${locks.path}/$digest.lock').open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        // Another process may already own the lock. Retry on the next check.
        return false;
      }
      if (mayPublish != null) {
        if (!mayPublish()) return false;
        if (await PlaylistRefreshSchedule.hours(profile.sourceKey) == 0) return false;
        if (!await PlaylistRefreshSchedule.automaticAttemptAllowed(profile.sourceKey)) return false;
        if (!repair && !await PlaylistRefreshSchedule.due(profile.sourceKey)) return false;
        if (!mayPublish()) return false;
        await PlaylistRefreshSchedule.markAutomaticAttempt(profile.sourceKey);
      }
      return await activate(profile, content, forceRefresh: true, mayPublish: mayPublish);
    } finally {
      try {
        if (locked) await handle?.unlock();
      } finally {
        try {
          await handle?.close();
        } finally {
          _refreshingSources.remove(profile.sourceKey);
        }
      }
    }
  }

  Future<bool> activate(PlaylistProfile profile, ContentProvider content, {bool forceRefresh = false, bool Function()? mayPublish, void Function(int completed, String stage)? onXtreamProgress, void Function(int live, int movies, int series)? onM3uProgress}) async {
    if (mayPublish != null && !mayPublish()) return false;
    // Normal activation first restores the persisted catalog (or an already
    // active in-memory catalog). This avoids downloading the same playlist
    // again when switching profiles or reopening the application. Explicit
    // refresh operations deliberately bypass the stored snapshot.
    if (!forceRefresh) {
      final restored = await content.restoreStoredLibrary(
        profile.sourceKey,
        sourceLabel: profile.displayName,
      );
      if (restored && content.isLoaded &&
          content.sourceKey == profile.sourceKey) {
        if (mayPublish != null && !mayPublish()) return false;
        await _profiles.setActive(profile.sourceKey,
            stillCurrent: () => content.isLoaded &&
                content.sourceKey == profile.sourceKey &&
                (mayPublish == null || mayPublish()));
        return content.isLoaded && content.sourceKey == profile.sourceKey &&
            (mayPublish == null || mayPublish());
      }
      if (mayPublish != null && !mayPublish()) return false;
    }
    final generation = content.beginLibraryActivation();
    final config = await _sources.read(profile.sourceKey);
    if (!content.isLibraryActivationCurrent(generation)) return false;
    if (config == null) {
      throw StateError('Für diese Playlist sind keine sicher gespeicherten Quelldaten vorhanden. Bitte füge sie erneut hinzu.');
    }
    if (config.type == 'm3u' && config.m3uUrl != null) {
      if (!await PlaylistParser.parseAndLoad(config.m3uUrl!, content,
          sourceKeyOverride: profile.sourceKey, activationGeneration: generation, mayPublish: mayPublish, durableRefresh: forceRefresh, onParseProgress: onM3uProgress)) return false;
    } else if (config.type == 'm3u' && config.localFilePath != null) {
      final file = File(config.localFilePath!);
      if (!await file.exists()) throw StateError('Die lokal gespeicherte M3U-Datei wurde nicht gefunden. Bitte importiere sie erneut.');
      if (!content.isLibraryActivationCurrent(generation)) return false;
      if (!await PlaylistParser.parseAndLoadFile(file.path, content,
          sourceKeyOverride: profile.sourceKey, activationGeneration: generation, mayPublish: mayPublish, durableRefresh: forceRefresh, onParseProgress: onM3uProgress)) return false;
    } else if (config.type == 'xtream' && config.serverUrl != null &&
        config.username != null && config.password != null) {
      final service = XtreamService(
        baseUrl: config.serverUrl!, username: config.username!, password: config.password!,
        sourceKey: profile.sourceKey,
      );
      try {
        final live = await service.getLiveStreams();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        onXtreamProgress?.call(1, 'live');
        final vod = await service.getVodStreams();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        onXtreamProgress?.call(2, 'vod');
        final series = await service.getSeries();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        if (forceRefresh && live.isEmpty && vod.isEmpty && series.isEmpty) {
          throw StateError('Empty refreshed catalog');
        }
        if (mayPublish != null && !mayPublish()) return false;
        if (forceRefresh) {
          if (!await content.replaceRefreshedLibrary(channels: live, vod: vod,
              series: series, sourceKey: profile.sourceKey,
              sourceLabel: profile.displayName, activationGeneration: generation,
              mayPublish: mayPublish)) return false;
        } else {
        content.replaceLibrary(
          channels: live, vod: vod, series: series,
          sourceKey: profile.sourceKey,
          sourceLabel: profile.displayName,
          activationGeneration: generation,
        );
        }
        // Report completion only after the fetched catalog has been
        // handed to ContentProvider, not merely after the final HTTP call.
        if (content.isLibraryActivationCurrent(generation)) {
          onXtreamProgress?.call(3, 'series');
        }
      } finally {
        service.close();
      }
    } else {
      throw StateError('Dieser Playlist-Typ kann derzeit nicht automatisch erneut geladen werden.');
    }
    if (!content.isLibraryActivationCurrent(generation) || (mayPublish != null && !mayPublish())) return false;
    if (forceRefresh) {
      await content.waitForCatalogWrites();
      if (!content.isLibraryActivationCurrent(generation)) return false;
      if (content.lastCatalogSaveError != null) {
        throw StateError("Catalog persistence failed");
      }
    }
    // Scheduled refreshes must not rewrite active-profile metadata.
    // Manual activation (including manual refresh) retains its existing behavior.
    if (mayPublish == null) {
      await _profiles.setActive(profile.sourceKey,
          stillCurrent: () => content.isLibraryActivationCurrent(generation) &&
              content.isLoaded && content.sourceKey == profile.sourceKey);
    }
    if (forceRefresh && content.isLibraryActivationCurrent(generation)) {
      await PlaylistRefreshSchedule.markSuccess(profile.sourceKey);
    }
    return content.isLibraryActivationCurrent(generation);
  }
}

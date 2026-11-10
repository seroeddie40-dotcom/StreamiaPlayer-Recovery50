import 'dart:io';
import '../models/playlist_profile.dart';
import '../providers/content_provider.dart';
import 'playlist_parser.dart';
import 'playlist_profile_store.dart';
import 'playlist_source_store.dart';
import 'xtream_service.dart';

/// Reloads a previously configured remote playlist without exposing secrets
/// to the profile metadata store.
class PlaylistSwitchService {
  final PlaylistSourceStore _sources;
  final PlaylistProfileStore _profiles;

  PlaylistSwitchService({PlaylistSourceStore? sources, PlaylistProfileStore? profiles})
      : _sources = sources ?? PlaylistSourceStore(),
        _profiles = profiles ?? PlaylistProfileStore();

  Future<bool> activate(PlaylistProfile profile, ContentProvider content) async {
    final generation = content.beginLibraryActivation();
    // A previously loaded source can be switched to immediately, even offline.
    if (content.activateCachedLibrary(profile.sourceKey, activationGeneration: generation)) {
      if (content.isLibraryActivationCurrent(generation)) {
        await _profiles.setActive(profile.sourceKey);
      }
      return content.isLibraryActivationCurrent(generation);
    }
    final config = await _sources.read(profile.sourceKey);
    if (!content.isLibraryActivationCurrent(generation)) return false;
    if (config == null) {
      throw StateError('Für diese Playlist sind keine sicher gespeicherten Quelldaten vorhanden. Bitte füge sie erneut hinzu.');
    }
    if (config.type == 'm3u' && config.m3uUrl != null) {
      await PlaylistParser.parseAndLoad(config.m3uUrl!, content,
          sourceKeyOverride: profile.sourceKey, activationGeneration: generation);
    } else if (config.type == 'm3u' && config.localFilePath != null) {
      final file = File(config.localFilePath!);
      if (!await file.exists()) throw StateError('Die lokal gespeicherte M3U-Datei wurde nicht gefunden. Bitte importiere sie erneut.');
      final text = await file.readAsString();
      if (!content.isLibraryActivationCurrent(generation)) return false;
      await PlaylistParser.parseAndLoad(text, content,
          sourceKeyOverride: profile.sourceKey, activationGeneration: generation);
    } else if (config.type == 'xtream' && config.serverUrl != null &&
        config.username != null && config.password != null) {
      final service = XtreamService(
        baseUrl: config.serverUrl!, username: config.username!, password: config.password!,
      );
      try {
        final live = await service.getLiveStreams();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        final vod = await service.getVodStreams();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        final series = await service.getSeries();
        if (!content.isLibraryActivationCurrent(generation)) return false;
        content.replaceLibrary(
          channels: live, vod: vod, series: series,
          sourceKey: profile.sourceKey,
          sourceLabel: profile.displayName,
          activationGeneration: generation,
        );
      } finally {
        service.close();
      }
    } else {
      throw StateError('Dieser Playlist-Typ kann derzeit nicht automatisch erneut geladen werden.');
    }
    if (!content.isLibraryActivationCurrent(generation)) return false;
    await _profiles.setActive(profile.sourceKey);
    return content.isLibraryActivationCurrent(generation);
  }
}

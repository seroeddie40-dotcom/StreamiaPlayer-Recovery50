
import '../models/playlist_profile.dart';
import '../models/playlist_source_config.dart';

import 'playlist_management_service.dart';
import 'playlist_source_store.dart';
import 'family_category_catalog_service.dart';

/// Connects existing Streamia playlists to
/// the family category catalog.
///
/// Does not modify playlist metadata,
/// credentials, content or playback.
///
/// Category permissions are managed separately
/// through FamilyProfileManagementService.
class FamilyPlaylistCategoryService {
  final PlaylistManagementService _playlists;
  final PlaylistSourceStore _sources;
  final FamilyCategoryCatalogService _catalog;

  FamilyPlaylistCategoryService({
    PlaylistManagementService? playlistManagement,
    PlaylistSourceStore? sourceStore,
    FamilyCategoryCatalogService? categoryCatalog,
  })  : _playlists =
            playlistManagement ?? PlaylistManagementService(),
        _sources = sourceStore ?? PlaylistSourceStore(),
        _catalog =
            categoryCatalog ?? FamilyCategoryCatalogService();

  /// Returns playlist metadata without credentials.
  Future<List<PlaylistProfile>> loadPlaylists() async {
    final profiles = await _playlists.loadProfiles();

    final result = List<PlaylistProfile>.from(profiles)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);

        if (order != 0) return order;

        return a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase());
      });

    return List.unmodifiable(result);
  }

  /// Ensures that the selected playlist still exists
  /// in the account's local playlist list.
  Future<PlaylistProfile> _requirePlaylist(
    String sourceKey,
  ) async {
    if (sourceKey.trim().isEmpty) {
      throw const FamilyPlaylistCategoryException(
        'Ungültige Playlistkennung.',
      );
    }

    final profiles = await _playlists.loadProfiles();

    for (final profile in profiles) {
      if (profile.sourceKey == sourceKey) {
        return profile;
      }
    }

    throw const FamilyPlaylistCategoryException(
      'Die ausgewählte Playlist existiert nicht mehr.',
    );
  }

  /// Reads the source configuration only after
  /// confirming that the playlist exists.
  Future<PlaylistSourceConfig> _requireSource(
    String sourceKey,
  ) async {
    final source = await _sources.read(sourceKey);

    if (source == null ||
        source.sourceKey != sourceKey) {
      throw const FamilyPlaylistCategoryException(
        'Die Playlist-Zugangsdaten fehlen.',
      );
    }

    return source;
  }

  bool _isXtreamType(String type) {
    final normalized = type.trim().toLowerCase();

    return normalized == 'xtream' ||
        normalized == 'xtream_codes' ||
        normalized == 'xc';
  }

  bool _isM3uType(String type) {
    final normalized = type.trim().toLowerCase();

    return normalized == 'm3u' ||
        normalized == 'm3u_url' ||
        normalized == 'm3u_file' ||
        normalized == 'local_m3u';
  }

  /// Loads original Xtream categories for one
  /// existing playlist.
  ///
  /// Category IDs and sourceKey remain separate.
  /// Credentials are never returned to callers.
  Future<List<FamilyContentCategory>>
      loadXtreamCategories({
    required String sourceKey,
    required FamilyContentType contentType,
  }) async {
    final profile = await _requirePlaylist(sourceKey);

    final source = await _requireSource(sourceKey);

    if (!_isXtreamType(profile.type) ||
        !_isXtreamType(source.type)) {
      throw const FamilyPlaylistCategoryException(
        'Diese Playlist ist keine Xtream-Quelle.',
      );
    }

    final serverUrl = source.serverUrl;
    final username = source.username;
    final password = source.password;

    if (serverUrl == null ||
        serverUrl.trim().isEmpty ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw const FamilyPlaylistCategoryException(
        'Die Xtream-Zugangsdaten sind unvollständig.',
      );
    }

    return _catalog.loadXtreamCategories(
      sourceKey: sourceKey,
      baseUrl: serverUrl,
      username: username,
      password: password,
      contentType: contentType,
    );
  }

  /// Loads Live TV, movie and series categories
  /// from one existing Xtream source.
  Future<List<FamilyContentCategory>>
      loadAllXtreamCategories({
    required String sourceKey,
  }) async {
    final profile = await _requirePlaylist(sourceKey);

    final source = await _requireSource(sourceKey);

    if (!_isXtreamType(profile.type) ||
        !_isXtreamType(source.type)) {
      throw const FamilyPlaylistCategoryException(
        'Diese Playlist ist keine Xtream-Quelle.',
      );
    }

    final serverUrl = source.serverUrl;
    final username = source.username;
    final password = source.password;

    if (serverUrl == null ||
        serverUrl.trim().isEmpty ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw const FamilyPlaylistCategoryException(
        'Die Xtream-Zugangsdaten sind unvollständig.',
      );
    }

    return _catalog.loadAllXtreamCategories(
      sourceKey: sourceKey,
      baseUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  /// Converts M3U groups already extracted by
  /// Streamia's existing parser.
  ///
  /// This method deliberately does not download
  /// or reparse the playlist.
  ///
  /// The caller must provide original group names
  /// for the correct content type.
  Future<List<FamilyContentCategory>>
      loadM3uCategoriesFromGroups({
    required String sourceKey,
    required FamilyContentType contentType,
    required Iterable<String> groupNames,
  }) async {
    final profile = await _requirePlaylist(sourceKey);

    final source = await _requireSource(sourceKey);

    if (!_isM3uType(profile.type) ||
        !_isM3uType(source.type)) {
      throw const FamilyPlaylistCategoryException(
        'Diese Playlist ist keine M3U-Quelle.',
      );
    }

    return _catalog.fromM3uGroups(
      sourceKey: sourceKey,
      contentType: contentType,
      groupNames: groupNames,
    );
  }

  /// Determines whether a stored playlist
  /// uses Xtream or M3U.
  ///
  /// This is intended for choosing the correct
  /// category-loading path in the UI.
  Future<FamilyPlaylistSourceType> loadSourceType(
    String sourceKey,
  ) async {
    final profile = await _requirePlaylist(sourceKey);

    final source = await _requireSource(sourceKey);

    if (_isXtreamType(profile.type) &&
        _isXtreamType(source.type)) {
      return FamilyPlaylistSourceType.xtream;
    }

    if (_isM3uType(profile.type) &&
        _isM3uType(source.type)) {
      return FamilyPlaylistSourceType.m3u;
    }

    throw const FamilyPlaylistCategoryException(
      'Der Playlisttyp wird nicht unterstützt '
      'oder die gespeicherten Typen stimmen '
      'nicht überein.',
    );
  }

  /// Releases the internally created HTTP client.
  ///
  /// Call when this service is no longer needed.
  void dispose() {
    _catalog.dispose();
  }
}

enum FamilyPlaylistSourceType {
  xtream,
  m3u,
}

class FamilyPlaylistCategoryException
    implements Exception {
  final String message;

  const FamilyPlaylistCategoryException(this.message);

  @override
  String toString() => message;
}

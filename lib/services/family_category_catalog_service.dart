
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum FamilyContentType {
  live,
  vod,
  series,
}

extension FamilyContentTypeValue on FamilyContentType {
  String get databaseValue {
    switch (this) {
      case FamilyContentType.live:
        return 'live';
      case FamilyContentType.vod:
        return 'vod';
      case FamilyContentType.series:
        return 'series';
    }
  }

  String get xtreamAction {
    switch (this) {
      case FamilyContentType.live:
        return 'get_live_categories';
      case FamilyContentType.vod:
        return 'get_vod_categories';
      case FamilyContentType.series:
        return 'get_series_categories';
    }
  }
}

class FamilyContentCategory {
  final String sourceKey;
  final FamilyContentType contentType;
  final String categoryKey;
  final String displayName;

  const FamilyContentCategory({
    required this.sourceKey,
    required this.contentType,
    required this.categoryKey,
    required this.displayName,
  });

  String get contentTypeKey => contentType.databaseValue;

  /// Unique identity within the category catalog.
  /// Do not use this as the database category_key.
  String get identity => jsonEncode([
        sourceKey,
        contentTypeKey,
        categoryKey,
      ]);
}

class FamilyCategoryCatalogException
    implements Exception {
  final String message;

  const FamilyCategoryCatalogException(this.message);

  @override
  String toString() => message;
}

/// Reads original categories from user-provided
/// Xtream accounts.
///
/// This service does not change playlists, streams,
/// playback, profile settings or Supabase rules.
///
/// For M3U, categories can be supplied by the
/// existing playlist parser through fromM3uGroups().
class FamilyCategoryCatalogService {
  final http.Client _client;
  final bool _ownsClient;

  final Duration requestTimeout;

  FamilyCategoryCatalogService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 25),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static Uri _validateBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());

    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FamilyCategoryCatalogException(
        'Ungültige Xtream-Serveradresse.',
      );
    }

    return uri;
  }

  static String _requireSourceKey(String sourceKey) {
    final value = sourceKey.trim();

    if (value.isEmpty || value.length > 500) {
      throw const FamilyCategoryCatalogException(
        'Ungültige Playlistquellen-Kennung.',
      );
    }

    return value;
  }

  static Uri _buildApiUri({
    required String baseUrl,
    required String username,
    required String password,
    required FamilyContentType contentType,
  }) {
    final base = _validateBaseUrl(baseUrl);

    if (username.isEmpty || password.isEmpty) {
      throw const FamilyCategoryCatalogException(
        'Xtream-Zugangsdaten fehlen.',
      );
    }

    final path = base.path.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    return base.replace(
      path: '$path/player_api.php',
      queryParameters: {
        'username': username,
        'password': password,
        'action': contentType.xtreamAction,
      },
    );
  }

  /// Loads the original category IDs and names.
  ///
  /// sourceKey must be the stable identifier
  /// already assigned to the playlist source.
  ///
  /// Never use passwords, stream URLs or
  /// display names as sourceKey.
  Future<List<FamilyContentCategory>>
      loadXtreamCategories({
    required String sourceKey,
    required String baseUrl,
    required String username,
    required String password,
    required FamilyContentType contentType,
  }) async {
    final stableSourceKey =
        _requireSourceKey(sourceKey);

    final uri = _buildApiUri(
      baseUrl: baseUrl,
      username: username,
      password: password,
      contentType: contentType,
    );

    try {
      final response =
          await _client.get(uri).timeout(requestTimeout);

      if (response.statusCode == 401 ||
          response.statusCode == 403) {
        throw const FamilyCategoryCatalogException(
          'Der Xtream-Zugang wurde abgelehnt.',
        );
      }

      if (response.statusCode != 200) {
        throw const FamilyCategoryCatalogException(
          'Xtream-Kategorien konnten nicht '
          'geladen werden.',
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
      } on FormatException {
        throw const FamilyCategoryCatalogException(
          'Ungültige Kategorieantwort des '
          'Xtream-Servers.',
        );
      }

      if (decoded is! List) {
        throw const FamilyCategoryCatalogException(
          'Der Xtream-Server hat keine '
          'gültige Kategorienliste geliefert.',
        );
      }

      final categories =
          <FamilyContentCategory>[];

      final seenIds = <String>{};

      for (final item in decoded) {
        if (item is! Map) continue;

        final rawId = item['category_id'];
        final rawName = item['category_name'];

        if (rawId == null) continue;

        final categoryId =
            rawId.toString().trim();

        if (categoryId.isEmpty ||
            categoryId.length > 500 ||
            !seenIds.add(categoryId)) {
          continue;
        }

        final name =
            rawName?.toString().trim() ?? '';

        categories.add(
          FamilyContentCategory(
            sourceKey: stableSourceKey,
            contentType: contentType,
            categoryKey: categoryId,
            displayName: name.isEmpty
                ? 'Kategorie $categoryId'
                : name,
          ),
        );
      }

      categories.sort(
        (a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()),
      );

      return List.unmodifiable(categories);
    } on TimeoutException {
      throw const FamilyCategoryCatalogException(
        'Zeitüberschreitung beim Laden '
        'der Xtream-Kategorien.',
      );
    } on SocketException {
      throw const FamilyCategoryCatalogException(
        'Keine Verbindung zum Xtream-Server.',
      );
    } on http.ClientException {
      throw const FamilyCategoryCatalogException(
        'Netzwerkfehler beim Laden '
        'der Xtream-Kategorien.',
      );
    }
  }

  /// Loads all three Xtream category types.
  ///
  /// Each type is requested separately.
  /// An error is propagated rather than
  /// silently treating unavailable categories
  /// as an empty catalog.
  Future<List<FamilyContentCategory>>
      loadAllXtreamCategories({
    required String sourceKey,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final results = await Future.wait([
      loadXtreamCategories(
        sourceKey: sourceKey,
        baseUrl: baseUrl,
        username: username,
        password: password,
        contentType: FamilyContentType.live,
      ),
      loadXtreamCategories(
        sourceKey: sourceKey,
        baseUrl: baseUrl,
        username: username,
        password: password,
        contentType: FamilyContentType.vod,
      ),
      loadXtreamCategories(
        sourceKey: sourceKey,
        baseUrl: baseUrl,
        username: username,
        password: password,
        contentType: FamilyContentType.series,
      ),
    ]);

    return List.unmodifiable(
      results.expand((items) => items),
    );
  }

  /// Converts original M3U group names into
  /// family-category catalog entries.
  ///
  /// The caller must use the same stable
  /// sourceKey as the playlist source store.
  ///
  /// M3U has no universal numeric category ID.
  /// Therefore the exact original group name
  /// is used as categoryKey.
  ///
  /// This method does not infer whether a group
  /// contains live TV, movies or series.
  /// The existing playlist parser must supply
  /// the correct contentType.
  List<FamilyContentCategory> fromM3uGroups({
    required String sourceKey,
    required FamilyContentType contentType,
    required Iterable<String> groupNames,
  }) {
    final stableSourceKey =
        _requireSourceKey(sourceKey);

    final uniqueNames = <String>{};

    for (final group in groupNames) {
      final name = group.trim();

      if (name.isEmpty || name.length > 500) {
        continue;
      }

      uniqueNames.add(name);
    }

    final categories = uniqueNames.map((name) {
      return FamilyContentCategory(
        sourceKey: stableSourceKey,
        contentType: contentType,
        categoryKey: name,
        displayName: name,
      );
    }).toList();

    categories.sort(
      (a, b) => a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase()),
    );

    return List.unmodifiable(categories);
  }

  /// Closes only the HTTP client created
  /// internally by this service.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

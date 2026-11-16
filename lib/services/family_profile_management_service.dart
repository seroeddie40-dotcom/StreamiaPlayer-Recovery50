
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyProfileManagementService {
  final SupabaseClient _client;

  FamilyProfileManagementService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw StateError(
        'Bitte zuerst bei Streamia Player anmelden.',
      );
    }
  }

  void _validateParentToken(String token) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw ArgumentError(
        'Eine gültige Eltern-PIN-Sitzung ist erforderlich.',
      );
    }
  }

  void _validateProfileId(String profileId) {
    if (profileId.trim().isEmpty) {
      throw ArgumentError('Profil-ID fehlt.');
    }
  }

  void _validateProfileName(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError(
        'Der Profilname muss 1 bis 60 Zeichen enthalten.',
      );
    }
  }

  void _validateAvatar(String? avatarKey) {
    if (avatarKey != null && avatarKey.length > 100) {
      throw ArgumentError(
        'Ungültiger Avatar-Schlüssel.',
      );
    }
  }

  void _validateContentType(String contentType) {
    if (!const {'live', 'vod', 'series'}
        .contains(contentType)) {
      throw ArgumentError(
        'Ungültiger Inhaltstyp.',
      );
    }
  }

  /// Liefert die aktuell zulässige Profilanzahl.
  ///
  /// Bei gesperrtem oder abgelaufenem Zugang
  /// liefert Supabase 0.
  Future<int> loadProfileLimit() async {
    _requireSignedIn();

    final result = await _client.rpc(
      'family_profile_limit',
    );

    if (result is num) {
      return result.toInt();
    }

    throw const FormatException(
      'Ungültige Antwort der Profilgrenzenprüfung.',
    );
  }

  /// Erstellt ein Erwachsenen- oder Kinderprofil.
  ///
  /// profileType: adult oder child.
  ///
  /// Supabase prüft Eltern-PIN-Sitzung,
  /// Tarifgrenze und Kontozugehörigkeit.
  Future<String> createProfile({
    required String parentAccessToken,
    required String displayName,
    required String profileType,
    String? avatarKey,
  }) async {
    _requireSignedIn();
    _validateParentToken(parentAccessToken);
    _validateProfileName(displayName);
    _validateAvatar(avatarKey);

    if (!const {'adult', 'child'}
        .contains(profileType)) {
      throw ArgumentError(
        'Der Profiltyp muss adult oder child sein.',
      );
    }

    final result = await _client.rpc(
      'create_family_profile',
      params: {
        'p_parent_token': parentAccessToken,
        'p_display_name': displayName.trim(),
        'p_profile_type': profileType,
        'p_avatar_key': avatarKey,
      },
    );

    if (result is String && result.isNotEmpty) {
      return result;
    }

    throw const FormatException(
      'Supabase hat keine gültige Profil-ID geliefert.',
    );
  }

  /// Ändert den Namen und Avatar eines Profils.
  Future<bool> updateProfile({
    required String parentAccessToken,
    required String profileId,
    required String displayName,
    String? avatarKey,
  }) async {
    _requireSignedIn();
    _validateParentToken(parentAccessToken);
    _validateProfileId(profileId);
    _validateProfileName(displayName);
    _validateAvatar(avatarKey);

    final result = await _client.rpc(
      'update_family_profile',
      params: {
        'p_parent_token': parentAccessToken,
        'p_profile_id': profileId,
        'p_display_name': displayName.trim(),
        'p_avatar_key': avatarKey,
      },
    );

    return result == true;
  }

  /// Legt ein Erwachsenenprofil als Standard fest.
  Future<bool> setDefaultProfile({
    required String parentAccessToken,
    required String profileId,
  }) async {
    _requireSignedIn();
    _validateParentToken(parentAccessToken);
    _validateProfileId(profileId);

    final result = await _client.rpc(
      'set_default_family_profile',
      params: {
        'p_parent_token': parentAccessToken,
        'p_profile_id': profileId,
      },
    );

    return result == true;
  }

  /// Löscht ein Profil.
  ///
  /// Das letzte Erwachsenenprofil und das
  /// aktuelle Standardprofil sind geschützt.
  Future<bool> deleteProfile({
    required String parentAccessToken,
    required String profileId,
  }) async {
    _requireSignedIn();
    _validateParentToken(parentAccessToken);
    _validateProfileId(profileId);

    final result = await _client.rpc(
      'delete_family_profile',
      params: {
        'p_parent_token': parentAccessToken,
        'p_profile_id': profileId,
      },
    );

    return result == true;
  }

  /// Gibt eine Kategorie für ein Kinderprofil
  /// frei oder sperrt sie.
  ///
  /// sourceKey: eindeutige Playlist-Quellenkennung.
  /// contentType: live, vod oder series.
  /// categoryKey: Kategoriekennung dieser Quelle.
  Future<bool> setChildCategoryVisibility({
    required String parentAccessToken,
    required String childProfileId,
    required String sourceKey,
    required String contentType,
    required String categoryKey,
    required bool isVisible,
  }) async {
    _requireSignedIn();
    _validateParentToken(parentAccessToken);
    _validateProfileId(childProfileId);
    _validateContentType(contentType);

    if (sourceKey.trim().isEmpty ||
        sourceKey.trim().length > 500 ||
        categoryKey.trim().isEmpty ||
        categoryKey.trim().length > 500) {
      throw ArgumentError(
        'Ungültige Playlist- oder Kategoriekennung.',
      );
    }

    final result = await _client.rpc(
      'set_family_category_visibility',
      params: {
        'p_parent_token': parentAccessToken,
        'p_profile_id': childProfileId,
        'p_source_key': sourceKey.trim(),
        'p_content_type': contentType,
        'p_category_key': categoryKey.trim(),
        'p_is_visible': isVisible,
      },
    );

    return result == true;
  }
}


import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/family_profile.dart';

class FamilyProfileService {
  final SupabaseClient _client;

  FamilyProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _accountUserId {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError(
        'Für Familienprofile ist eine Anmeldung erforderlich.',
      );
    }

    return userId;
  }

  /// Lädt ausschließlich Profile des angemeldeten Kontos.
  /// Die Datenbank erzwingt zusätzlich ihre RLS-Regeln.
  Future<List<FamilyProfile>> loadProfiles() async {
    final accountId = _accountUserId;

    final rows = await _client
        .from('family_profiles')
        .select(
          'id, account_user_id, display_name, '
          'avatar_key, profile_type, is_default, sort_order',
        )
        .eq('account_user_id', accountId)
        .order('sort_order', ascending: true);

    return rows
        .map((row) => FamilyProfile.fromJson(row))
        .toList(growable: false);
  }

  /// Requests the server-authorized, unprotected default profile.
  /// Errors must propagate: a failed request is not an authorization grant.
  Future<FamilyProfile> ensureDefaultProfile() async {
    final accountId = _accountUserId;
    final result = await _client.rpc('ensure_default_family_profile');
    if (result is! String || result.isEmpty ||
        _accountUserId != accountId) {
      throw StateError('Invalid default profile response');
    }
    final profiles = await loadProfiles();
    if (_accountUserId != accountId || profiles.any((p) => p.isChild)) {
      throw StateError('Protected family account');
    }
    for (final profile in profiles) {
      if (profile.id == result && profile.accountUserId == accountId &&
          profile.isAdult && profile.isDefault) {
        return profile;
      }
    }
    throw StateError('Default profile could not be verified');
  }

  /// Ermittelt das Standardprofil des angemeldeten Kontos.
  /// Gibt null zurück, wenn noch keine Profile existieren.
  Future<FamilyProfile?> loadDefaultProfile() async {
    final profiles = await loadProfiles();

    if (profiles.isEmpty) return null;

    for (final profile in profiles) {
      if (profile.isDefault) return profile;
    }

    return profiles.first;
  }

  /// Lädt die gespeicherten Sichtbarkeitsregeln eines Profils.
  /// Das Ergebnis ist keine Wiedergabeberechtigung.
  ///
  /// Fehlende Regeln bedeuten standardmäßig sichtbar.
  Future<List<Map<String, dynamic>>> loadCategoryRules(
    String familyProfileId,
  ) async {
    final accountId = _accountUserId;

    if (familyProfileId.isEmpty) {
      throw ArgumentError.value(
        familyProfileId,
        'familyProfileId',
      );
    }

    final rows = await _client
        .from('family_profile_category_rules')
        .select(
          'family_profile_id, source_key, content_type, '
          'category_key, is_visible',
        )
        .eq('account_user_id', accountId)
        .eq('family_profile_id', familyProfileId);

    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Prüft lediglich die gespeicherte Ordnersichtbarkeit.
  ///
  /// Diese Methode darf NICHT als alleinige
  /// Sicherheitsprüfung für die Wiedergabe verwendet werden.
  bool isChildCategoryVisible({
    required List<Map<String, dynamic>> rules,
    required String sourceKey,
    required String contentType,
    required String categoryKey,
  }) {
    if (!const {'live', 'vod', 'series'}
        .contains(contentType)) {
      return false;
    }

    for (final rule in rules) {
      if (rule['source_key'] == sourceKey &&
          rule['content_type'] == contentType &&
          rule['category_key'] == categoryKey) {
        return rule['is_visible'] != false;
      }
    }

    // Ohne explizite Sperre ist der Ordner sichtbar.
    return true;
  }
}

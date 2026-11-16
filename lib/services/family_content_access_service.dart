
import 'package:flutter/foundation.dart';

import '../models/family_profile.dart';
import 'family_profile_service.dart';

/// Evaluates category visibility for family profiles.
///
/// IMPORTANT:
/// This service is a client-side policy evaluator.
/// It does not replace server-side authorization.
///
/// Every content entry point must call this service
/// before exposing or playing restricted content.
class FamilyContentAccessService {
  FamilyContentAccessService({
    FamilyProfileService? profileService,
  }) : _profiles =
           profileService ?? FamilyProfileService();

  final FamilyProfileService _profiles;

  static const Set<String> _contentTypes = {
    'live',
    'vod',
    'series',
  };

  /// Loads a fresh snapshot of the child's
  /// category permissions from Supabase.
  ///
  /// Adult profiles do not require child rules.
  Future<FamilyContentAccessSnapshot> loadSnapshot({
    required FamilyProfile profile,
  }) async {
    if (profile.type == FamilyProfileType.adult) {
      return FamilyContentAccessSnapshot._(
        profileId: profile.id,
        isChild: false,
        rulesLoaded: true,
        rules: const [],
      );
    }

    if (profile.type != FamilyProfileType.child) {
      return FamilyContentAccessSnapshot._(
        profileId: profile.id,
        isChild: true,
        rulesLoaded: false,
        rules: const [],
      );
    }

    try {
      final rules = await _profiles.loadCategoryRules(
        profile.id,
      );

      final copiedRules = rules
          .map(
            (rule) =>
                Map<String, dynamic>.unmodifiable(rule),
          )
          .toList(growable: false);

      return FamilyContentAccessSnapshot._(
        profileId: profile.id,
        isChild: true,
        rulesLoaded: true,
        rules: List.unmodifiable(copiedRules),
      );
    } catch (_) {
      // Fail closed: never grant child access
      // when permissions cannot be loaded.
      return FamilyContentAccessSnapshot._(
        profileId: profile.id,
        isChild: true,
        rulesLoaded: false,
        rules: const [],
      );
    }
  }

  /// Checks a single category using fresh rules.
  ///
  /// Returns false for a child if the server
  /// cannot be reached or rules cannot be loaded.
  Future<bool> canAccessCategory({
    required FamilyProfile profile,
    required String sourceKey,
    required String contentType,
    required String categoryKey,
  }) async {
    final snapshot = await loadSnapshot(
      profile: profile,
    );

    return snapshot.canAccessCategory(
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKey: categoryKey,
    );
  }

  /// Filters category-bearing content items
  /// using one permission snapshot.
  ///
  /// The caller must supply the original
  /// category key, not a translated display name.
  Future<List<T>> filterItems<T>({
    required FamilyProfile profile,
    required Iterable<T> items,
    required String sourceKey,
    required String contentType,
    required String? Function(T item) categoryKeyOf,
  }) async {
    final snapshot = await loadSnapshot(
      profile: profile,
    );

    return snapshot.filterItems(
      items: items,
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKeyOf: categoryKeyOf,
    );
  }
}

/// An immutable permission snapshot.
///
/// Use a fresh snapshot when entering a content
/// screen or starting a new playback request.
///
/// Do not persist this object as a permanent
/// authorization grant.
class FamilyContentAccessSnapshot {
  const FamilyContentAccessSnapshot._({
    required this.profileId,
    required this.isChild,
    required this.rulesLoaded,
    required this.rules,
  });

  /// Test-only constructor for exercising the real authorization policy
  /// without a Supabase connection. Production code must use loadSnapshot.
  @visibleForTesting
  factory FamilyContentAccessSnapshot.forTesting({
    required String profileId,
    required bool isChild,
    required bool rulesLoaded,
    required List<Map<String, dynamic>> rules,
  }) => FamilyContentAccessSnapshot._(
    profileId: profileId,
    isChild: isChild,
    rulesLoaded: rulesLoaded,
    rules: List.unmodifiable(rules.map(
      (rule) => Map<String, dynamic>.unmodifiable(rule),
    )),
  );

  final String profileId;
  final bool isChild;
  final bool rulesLoaded;

  final List<Map<String, dynamic>> rules;

  static const Set<String> _validContentTypes = {
    'live',
    'vod',
    'series',
  };

  /// True only when the current permission
  /// snapshot is usable.
  bool get isReady => rulesLoaded;

  /// Checks whether an item in this category
  /// may be accessed by the selected profile.
  bool canAccessCategory({
    required String sourceKey,
    required String contentType,
    required String categoryKey,
  }) {
    final normalizedSourceKey = sourceKey.trim();
    final normalizedContentType =
        contentType.trim().toLowerCase();
    final normalizedCategoryKey = categoryKey.trim();

    // No permissions loaded: fail closed.
    if (!rulesLoaded) return false;

    // Adult profiles are not subject to child category restrictions.
    if (!isChild) return true;

    // Child identifiers must match the original playlist metadata.
    if (normalizedSourceKey.isEmpty ||
        normalizedCategoryKey.isEmpty ||
        !_validContentTypes.contains(
          normalizedContentType,
        )) {
      return false;
    }


    // Explicit blocks override the default-visible policy.
    for (final rule in rules) {
      if (rule['source_key'] == normalizedSourceKey &&
          rule['content_type'] ==
              normalizedContentType &&
          rule['category_key'] ==
              normalizedCategoryKey) {
        return rule['is_visible'] != false;
      }
    }

    return true;
  }

  /// Non-sensitive counts for diagnosing an unexpectedly empty child catalog.
  /// No stream URLs, credentials, titles or profile identifiers are exposed.
  String catalogDiagnostics<T>({
    required Iterable<T> items,
    required String sourceKey,
    required String contentType,
    required String? Function(T) categoryKeyOf,
  }) {
    final entries = items.toList(growable: false);
    final missing = entries.where((item) =>
        (categoryKeyOf(item) ?? '').trim().isEmpty).length;
    final permitted = entries.where((item) => canAccessCategory(
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKey: categoryKeyOf(item) ?? '',
    )).length;
    final blocked = rules.where((rule) =>
      rule['source_key'] == sourceKey.trim() &&
      rule['content_type'] == contentType.trim().toLowerCase() &&
      rule['is_visible'] == false,
    ).length;
    return 'Diagnose: geladen ${entries.length}, freigegeben $permitted, '
        'ohne Kategorie-ID $missing, gespeicherte Sperren $blocked, '
        'Regeln geladen: $rulesLoaded';
  }

  /// Returns only content items allowed by
  /// this permission snapshot.
  ///
  /// Child items without a usable category key are excluded.
  /// Adults can still see uncategorized items.
  List<T> filterItems<T>({
    required Iterable<T> items,
    required String sourceKey,
    required String contentType,
    required String? Function(T item) categoryKeyOf,
  }) {
    final result = <T>[];

    for (final item in items) {
      final categoryKey = categoryKeyOf(item);

      // A missing original category ID cannot be matched to a parent block.
      // Adults retain access; children must wait for valid source metadata.
      // This matches canAccessCategory and prevents bypass via empty IDs.
      if (categoryKey == null || categoryKey.trim().isEmpty) {
        if (rulesLoaded && !isChild) result.add(item);
        continue;
      }

      if (canAccessCategory(
        sourceKey: sourceKey,
        contentType: contentType,
        categoryKey: categoryKey,
      )) {
        result.add(item);
      }
    }

    return List<T>.unmodifiable(result);
  }
}

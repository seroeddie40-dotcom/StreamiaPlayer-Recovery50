
import 'package:flutter/foundation.dart';

import '../models/family_profile.dart';
import '../services/family_content_access_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_service.dart';

/// Manages the active family profile during this app session.
///
/// Adult profiles require successful PIN verification.
/// Child profiles require successfully loaded permissions.
///
/// No profile is automatically activated after app restart.
///
/// IMPORTANT:
/// This is client-side access control.
/// Server-side authorization remains necessary.
class FamilySessionProvider extends ChangeNotifier {
  FamilySessionProvider({
    FamilyContentAccessService? accessService,
    FamilyPinService? pinService,
    FamilyProfileService? profileService,
  })  : _accessService =
            accessService ?? FamilyContentAccessService(),
        _pinService = pinService ?? FamilyPinService(),
        _profileService =
            profileService ?? FamilyProfileService();

  final FamilyContentAccessService _accessService;
  final FamilyPinService _pinService;
  final FamilyProfileService _profileService;

  FamilyProfile? _activeProfile;
  FamilyContentAccessSnapshot? _snapshot;

  bool _isLoading = false;
  int _generation = 0;

  FamilyProfile? get activeProfile => _activeProfile;

  FamilyContentAccessSnapshot? get snapshot => _snapshot;

  bool get hasActiveProfile => _activeProfile != null;

  bool get isLoading => _isLoading;

  bool get isChild =>
      _activeProfile?.type == FamilyProfileType.child;

  bool get isAdult =>
      _activeProfile?.type == FamilyProfileType.adult;

  bool get isReady =>
      !_isLoading &&
      _activeProfile != null &&
      _snapshot != null &&
      _snapshot!.profileId == _activeProfile!.id &&
      _snapshot!.isReady;

  /// Activates a profile.
  ///
  /// Adult profiles require their PIN.
  /// Child profiles do not require an adult PIN,
  /// but their category permissions must load.
  ///
  /// Returns false if activation is not permitted.
  Future<bool> activateProfile(
    FamilyProfile profile, {
    String? adultPin,
  }) async {
    final generation = ++_generation;

    // Invalidate the previous session immediately.
    _activeProfile = null;
    _snapshot = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Ensure the selected profile still belongs
      // to the currently authenticated account.
      final profiles = await _profileService.loadProfiles();

      if (generation != _generation) {
        return false;
      }

      FamilyProfile? verifiedProfile;

      for (final candidate in profiles) {
        if (candidate.id == profile.id) {
          verifiedProfile = candidate;
          break;
        }
      }

      if (verifiedProfile == null) {
        _finishFailedActivation(generation);
        return false;
      }

      // Use the fresh server-loaded profile type,
      // not a potentially outdated UI object.
      if (verifiedProfile.type == FamilyProfileType.adult) {
        if (adultPin == null ||
            !RegExp(r'^[0-9]{4,12}$').hasMatch(adultPin)) {
          _finishFailedActivation(generation);
          return false;
        }

        final verification = await _pinService.verifyPin(
          scope: FamilyPinScope.adult,
          pin: adultPin,
          familyProfileId: verifiedProfile.id,
        );

        if (generation != _generation) {
          return false;
        }

        if (!verification.isSuccessful) {
          _finishFailedActivation(generation);
          return false;
        }
      } else if (verifiedProfile.type !=
          FamilyProfileType.child) {
        _finishFailedActivation(generation);
        return false;
      }

      final loaded = await _accessService.loadSnapshot(
        profile: verifiedProfile,
      );

      if (generation != _generation) {
        return false;
      }

      if (!loaded.isReady ||
          loaded.profileId != verifiedProfile.id ||
          loaded.isChild !=
              (verifiedProfile.type ==
                  FamilyProfileType.child)) {
        _finishFailedActivation(generation);
        return false;
      }

      _activeProfile = verifiedProfile;
      _snapshot = loaded;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (_) {
      _finishFailedActivation(generation);
      return false;
    }
  }

  void _finishFailedActivation(int generation) {
    if (generation != _generation) return;

    _activeProfile = null;
    _snapshot = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Reloads the active profile and its permissions.
  ///
  /// Adult PIN verification is not repeated within
  /// an already active adult session.
  ///
  /// The session is cleared if the profile is removed
  /// or its type changes.
  Future<bool> refreshPermissions() async {
    final profile = _activeProfile;

    if (profile == null) return false;

    final generation = ++_generation;

    _snapshot = null;
    _isLoading = true;
    notifyListeners();

    try {
      final profiles = await _profileService.loadProfiles();

      if (generation != _generation) {
        return false;
      }

      FamilyProfile? currentProfile;

      for (final candidate in profiles) {
        if (candidate.id == profile.id) {
          currentProfile = candidate;
          break;
        }
      }

      if (currentProfile == null ||
          currentProfile.type != profile.type) {
        _finishFailedActivation(generation);
        return false;
      }

      final loaded = await _accessService.loadSnapshot(
        profile: currentProfile,
      );

      if (generation != _generation) {
        return false;
      }

      if (!loaded.isReady ||
          loaded.profileId != currentProfile.id ||
          loaded.isChild !=
              (currentProfile.type ==
                  FamilyProfileType.child)) {
        _finishFailedActivation(generation);
        return false;
      }

      _activeProfile = currentProfile;
      _snapshot = loaded;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (_) {
      _finishFailedActivation(generation);
      return false;
    }
  }

  /// Checks category visibility for the active profile.
  ///
  /// No active or ready session means no access.
  bool canAccessCategory({
    required String sourceKey,
    required String contentType,
    required String categoryKey,
  }) {
    if (!isReady) return false;

    return _snapshot!.canAccessCategory(
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKey: categoryKey,
    );
  }

  /// Filters items using the current permission snapshot.
  List<T> filterItems<T>({
    required Iterable<T> items,
    required String sourceKey,
    required String contentType,
    required String? Function(T item) categoryKeyOf,
  }) {
    if (!isReady) {
      return List<T>.unmodifiable(<T>[]);
    }

    return _snapshot!.filterItems(
      items: items,
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKeyOf: categoryKeyOf,
    );
  }

  /// Immediately ends the active family session.
  void clearSession() {
    ++_generation;
    _activeProfile = null;
    _snapshot = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }
}

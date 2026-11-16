
import 'package:flutter/foundation.dart';

import '../models/family_profile.dart';
import '../services/family_content_access_service.dart';

/// Holds the active family profile for the current app session.
///
/// A family profile must be selected explicitly.
/// Adult access is never restored automatically after restart.
///
/// This provider handles client-side visibility only.
/// Playback and server-side authorization must also be enforced.
class FamilySessionProvider extends ChangeNotifier {
  FamilySessionProvider({
    FamilyContentAccessService? accessService,
  }) : _accessService =
           accessService ?? FamilyContentAccessService();

  final FamilyContentAccessService _accessService;

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

  /// A child session is ready only after its permissions
  /// have been successfully loaded.
  bool get isReady =>
      _activeProfile != null &&
      _snapshot != null &&
      _snapshot!.profileId == _activeProfile!.id &&
      _snapshot!.isReady &&
      !_isLoading;

  /// Selects a family profile and loads its permissions.
  ///
  /// The calling screen must verify the adult PIN
  /// before passing an adult profile here.
  ///
  /// This method does not verify PINs itself.
  Future<bool> activateProfile(FamilyProfile profile) async {
    final generation = ++_generation;

    // Clear the previous session immediately.
    _activeProfile = null;
    _snapshot = null;
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await _accessService.loadSnapshot(
        profile: profile,
      );

      if (generation != _generation) {
        return false;
      }

      if (!loaded.isReady ||
          loaded.profileId != profile.id) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _activeProfile = profile;
      _snapshot = loaded;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (_) {
      if (generation != _generation) {
        return false;
      }

      _activeProfile = null;
      _snapshot = null;
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Refreshes permissions for the active profile.
  ///
  /// Old permissions are invalidated before the
  /// refresh starts, preventing stale child access.
  Future<bool> refreshPermissions() async {
    final profile = _activeProfile;

    if (profile == null) {
      return false;
    }

    final generation = ++_generation;

    _snapshot = null;
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await _accessService.loadSnapshot(
        profile: profile,
      );

      if (generation != _generation) {
        return false;
      }

      _snapshot = loaded.isReady &&
              loaded.profileId == profile.id
          ? loaded
          : null;

      _isLoading = false;
      notifyListeners();

      return _snapshot != null;
    } catch (_) {
      if (generation != _generation) {
        return false;
      }

      _snapshot = null;
      _isLoading = false;
      notifyListeners();

      return false;
    }
  }

  /// Checks category access in the current session.
  ///
  /// No active profile means no access.
  bool canAccessCategory({
    required String sourceKey,
    required String contentType,
    required String categoryKey,
  }) {
    if (!isReady) {
      return false;
    }

    return _snapshot!.canAccessCategory(
      sourceKey: sourceKey,
      contentType: contentType,
      categoryKey: categoryKey,
    );
  }

  /// Filters items using the active permission snapshot.
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

  /// Ends the current family session.
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


import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/family_profile.dart';
import '../services/family_content_access_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_service.dart';

/// Manages the active family profile for the
/// currently authenticated Supabase account.
///
/// Adult profiles require successful PIN verification.
/// Child profiles require successfully loaded permissions.
///
/// No profile is automatically activated after restart.
///
/// IMPORTANT:
/// This is client-side access control.
/// Playback and server-side authorization must
/// also enforce the relevant restrictions.
class FamilySessionProvider extends ChangeNotifier {
  FamilySessionProvider({
    FamilyContentAccessService? accessService,
    FamilyPinService? pinService,
    FamilyProfileService? profileService,
    SupabaseClient? client,
  })  : _accessService =
            accessService ?? FamilyContentAccessService(),
        _pinService = pinService ?? FamilyPinService(),
        _profileService =
            profileService ?? FamilyProfileService(),
        _client = client ?? Supabase.instance.client {
    _authSubscription =
        _client.auth.onAuthStateChange.listen((event) {
      final currentAccountId =
          _client.auth.currentUser?.id;

      // Never retain a session after sign-out
      // or after switching to another account.
      if (event.event == AuthChangeEvent.signedOut ||
          (_sessionAccountId != null &&
              currentAccountId != _sessionAccountId)) {
        clearSession();
      }
    });
  }

  final FamilyContentAccessService _accessService;
  final FamilyPinService _pinService;
  final FamilyProfileService _profileService;
  final SupabaseClient _client;

  StreamSubscription<AuthState>? _authSubscription;

  FamilyProfile? _activeProfile;
  FamilyContentAccessSnapshot? _snapshot;

  String? _sessionAccountId;

  bool _isLoading = false;
  bool _disposed = false;
  int _generation = 0;

  FamilyProfile? get activeProfile {
    if (!_belongsToCurrentAccount) return null;
    return _activeProfile;
  }

  FamilyContentAccessSnapshot? get snapshot {
    if (!_belongsToCurrentAccount) return null;
    return _snapshot;
  }

  bool get hasActiveProfile => activeProfile != null;

  bool get isLoading => _isLoading;

  bool get isChild =>
      activeProfile?.type == FamilyProfileType.child;

  bool get isAdult =>
      activeProfile?.type == FamilyProfileType.adult;

  bool get _belongsToCurrentAccount {
    final currentAccountId =
        _client.auth.currentUser?.id;

    return currentAccountId != null &&
        _sessionAccountId != null &&
        currentAccountId == _sessionAccountId &&
        _activeProfile != null &&
        _activeProfile!.accountUserId ==
            currentAccountId;
  }

  bool get isReady =>
      !_isLoading &&
      _belongsToCurrentAccount &&
      _snapshot != null &&
      _snapshot!.profileId == _activeProfile!.id &&
      _snapshot!.isReady;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Activates a profile for the currently
  /// authenticated Supabase account.
  ///
  /// Adult profiles require their PIN.
  /// Child profiles require valid permissions.
  Future<bool> activateProfile(
    FamilyProfile profile, {
    String? adultPin,
  }) async {
    final generation = ++_generation;

    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;
    _isLoading = true;
    _notify();

    try {
      final accountId = _client.auth.currentUser?.id;

      if (accountId == null) {
        _finishFailedActivation(generation);
        return false;
      }

      final profiles =
          await _profileService.loadProfiles();

      if (generation != _generation ||
          _client.auth.currentUser?.id != accountId) {
        _finishFailedActivation(generation);
        return false;
      }

      FamilyProfile? verifiedProfile;

      for (final candidate in profiles) {
        if (candidate.id == profile.id &&
            candidate.accountUserId == accountId) {
          verifiedProfile = candidate;
          break;
        }
      }

      if (verifiedProfile == null) {
        _finishFailedActivation(generation);
        return false;
      }

      if (verifiedProfile.type ==
          FamilyProfileType.adult) {
        if (adultPin == null ||
            !RegExp(r'^[0-9]{4,12}$')
                .hasMatch(adultPin)) {
          _finishFailedActivation(generation);
          return false;
        }

        final verification =
            await _pinService.verifyPin(
          scope: FamilyPinScope.adult,
          pin: adultPin,
          familyProfileId: verifiedProfile.id,
        );

        if (generation != _generation ||
            _client.auth.currentUser?.id != accountId) {
          _finishFailedActivation(generation);
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

      final loaded =
          await _accessService.loadSnapshot(
        profile: verifiedProfile,
      );

      if (generation != _generation ||
          _client.auth.currentUser?.id != accountId) {
        _finishFailedActivation(generation);
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
      _sessionAccountId = accountId;
      _isLoading = false;
      _notify();

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
    _sessionAccountId = null;
    _isLoading = false;
    _notify();
  }

  /// Reloads the active profile and its
  /// category permissions.
  ///
  /// Previous permissions are invalidated
  /// before requesting fresh data.
  Future<bool> refreshPermissions() async {
    final profile = activeProfile;
    final accountId = _sessionAccountId;

    if (profile == null || accountId == null) {
      clearSession();
      return false;
    }

    final generation = ++_generation;

    _snapshot = null;
    _isLoading = true;
    _notify();

    try {
      final profiles =
          await _profileService.loadProfiles();

      if (generation != _generation ||
          _client.auth.currentUser?.id != accountId) {
        _finishFailedActivation(generation);
        return false;
      }

      FamilyProfile? currentProfile;

      for (final candidate in profiles) {
        if (candidate.id == profile.id &&
            candidate.accountUserId == accountId) {
          currentProfile = candidate;
          break;
        }
      }

      if (currentProfile == null ||
          currentProfile.type != profile.type) {
        _finishFailedActivation(generation);
        return false;
      }

      final loaded =
          await _accessService.loadSnapshot(
        profile: currentProfile,
      );

      if (generation != _generation ||
          _client.auth.currentUser?.id != accountId) {
        _finishFailedActivation(generation);
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
      _sessionAccountId = accountId;
      _isLoading = false;
      _notify();

      return true;
    } catch (_) {
      _finishFailedActivation(generation);
      return false;
    }
  }

  /// Checks category access for the active session.
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

  /// Filters content using the active
  /// profile's permission snapshot.
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

  /// Immediately invalidates the current
  /// family session and pending requests.
  void clearSession() {
    ++_generation;

    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;
    _isLoading = false;

    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _authSubscription?.cancel();
    super.dispose();
  }
}

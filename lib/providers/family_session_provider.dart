
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/family_profile.dart';
import '../services/family_content_access_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_service.dart';

/// Controls the active family profile.
///
/// Adult profiles use the account-level parent PIN.
/// Child profiles do not require a PIN.
///
/// Child permissions are refreshed every 60 seconds
/// and when the application returns to the foreground.
///
/// If a permission refresh fails, child content is
/// denied until a successful refresh completes.
class FamilySessionProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  FamilySessionProvider({
    FamilyContentAccessService? accessService,
    FamilyPinService? pinService,
    FamilyProfileService? profileService,
    SupabaseClient? client,
  })  : _accessService =
            accessService ?? FamilyContentAccessService(),
        _pinService = pinService ?? FamilyPinService(),
        _profileService = profileService ?? FamilyProfileService(),
        _client = client ?? Supabase.instance.client {
    WidgetsBinding.instance.addObserver(this);

    _authSubscription =
        _client.auth.onAuthStateChange.listen((event) {
      final currentAccountId =
          _client.auth.currentUser?.id;

      if (event.event == AuthChangeEvent.signedOut ||
          (_sessionAccountId != null &&
              currentAccountId != _sessionAccountId)) {
        clearSession();
      }
    });
  }

  static const Duration _childRefreshInterval =
      Duration(seconds: 60);

  final FamilyContentAccessService _accessService;
  final FamilyPinService _pinService;
  final FamilyProfileService _profileService;
  final SupabaseClient _client;

  StreamSubscription<AuthState>? _authSubscription;

  Timer? _adultExpiryTimer;
  Timer? _childRefreshTimer;

  FamilyProfile? _activeProfile;
  FamilyContentAccessSnapshot? _snapshot;
  String? _sessionAccountId;

  String? _adultAccessToken;
  DateTime? _adultValidUntil;

  bool _isLoading = false;
  bool _refreshing = false;
  bool _disposed = false;

  int _generation = 0;

  bool get _belongsToCurrentAccount {
    final accountId = _client.auth.currentUser?.id;

    return accountId != null &&
        _sessionAccountId == accountId &&
        _activeProfile != null &&
        _activeProfile!.accountUserId == accountId;
  }

  bool get _adultSessionCurrent {
    if (_activeProfile?.type != FamilyProfileType.adult) {
      return true;
    }

    final expiry = _adultValidUntil;

    return _adultAccessToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
  }

  FamilyProfile? get activeProfile {
    if (!_belongsToCurrentAccount ||
        !_adultSessionCurrent) {
      return null;
    }

    return _activeProfile;
  }

  FamilyContentAccessSnapshot? get snapshot {
    if (!_belongsToCurrentAccount ||
        !_adultSessionCurrent) {
      return null;
    }

    return _snapshot;
  }

  bool get hasActiveProfile => activeProfile != null;

  bool get isLoading => _isLoading;

  bool get isRefreshingPermissions => _refreshing;

  bool get isChild =>
      activeProfile?.type == FamilyProfileType.child;

  bool get isAdult =>
      activeProfile?.type == FamilyProfileType.adult;

  bool get isReady {
    final profile = activeProfile;
    final currentSnapshot = snapshot;

    if (profile == null ||
        currentSnapshot == null ||
        _isLoading ||
        _refreshing ||
        !currentSnapshot.isReady ||
        currentSnapshot.profileId != profile.id ||
        currentSnapshot.isChild !=
            (profile.type == FamilyProfileType.child)) {
      return false;
    }

    return true;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _cancelAdultExpiry() {
    _adultExpiryTimer?.cancel();
    _adultExpiryTimer = null;

    _adultAccessToken = null;
    _adultValidUntil = null;
  }

  void _stopChildRefresh() {
    _childRefreshTimer?.cancel();
    _childRefreshTimer = null;
  }

  void _scheduleAdultExpiry(DateTime expiry) {
    _adultExpiryTimer?.cancel();

    final remaining = expiry.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      clearSession();
      return;
    }

    _adultExpiryTimer = Timer(
      remaining,
      clearSession,
    );
  }

  void _startChildRefresh() {
    _stopChildRefresh();

    if (_disposed ||
        !_belongsToCurrentAccount ||
        _activeProfile?.type != FamilyProfileType.child) {
      return;
    }

    _childRefreshTimer = Timer.periodic(
      _childRefreshInterval,
      (_) {
        if (_disposed || _refreshing || _isLoading) {
          return;
        }

        if (_activeProfile?.type != FamilyProfileType.child ||
            !_belongsToCurrentAccount) {
          _stopChildRefresh();
          return;
        }

        // Timer callbacks cannot await a Future.
        // refreshPermissions handles errors internally.
        unawaited(refreshPermissions());
      },
    );
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (_disposed) return;

    if (state == AppLifecycleState.resumed) {
      if (_activeProfile?.type == FamilyProfileType.child &&
          _belongsToCurrentAccount &&
          !_isLoading &&
          !_refreshing) {
        unawaited(refreshPermissions());
      }
    }
  }

  /// Activates a profile after verifying account ownership.
  ///
  /// The parameter adultPin is retained for compatibility
  /// with existing screens. It contains the PARENT PIN.
  Future<bool> activateProfile(
    FamilyProfile profile, {
    String? adultPin,
  }) async {
    final generation = ++_generation;

    _stopChildRefresh();
    _cancelAdultExpiry();

    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;

    _refreshing = false;
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

      if (!_isCurrentRequest(generation, accountId)) {
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

      String? adultToken;
      DateTime? adultExpiry;

      if (verifiedProfile.type ==
          FamilyProfileType.adult) {
        if (adultPin == null ||
            !RegExp(r'^[0-9]{6,10}$')
                .hasMatch(adultPin)) {
          _finishFailedActivation(generation);
          return false;
        }

        final verification =
            await _pinService.verifyPin(
          scope: FamilyPinScope.parent,
          pin: adultPin,
        );

        if (!_isCurrentRequest(generation, accountId)) {
          return false;
        }

        if (!verification.isSuccessful ||
            verification.accessToken == null ||
            verification.validUntil == null ||
            !verification.validUntil!
                .isAfter(DateTime.now())) {
          _finishFailedActivation(generation);
          return false;
        }

        adultToken = verification.accessToken;
        adultExpiry = verification.validUntil;

        final sessionValid =
            await _pinService.checkSession(
          scope: FamilyPinScope.parent,
          accessToken: adultToken!,
        );

        if (!_isCurrentRequest(generation, accountId)) {
          return false;
        }

        if (!sessionValid ||
            !adultExpiry!.isAfter(DateTime.now())) {
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

      if (!_isCurrentRequest(generation, accountId)) {
        return false;
      }

      if (!loaded.isReady ||
          loaded.profileId != verifiedProfile.id ||
          loaded.isChild !=
              (verifiedProfile.type ==
                  FamilyProfileType.child) ||
          (adultExpiry != null &&
              !adultExpiry.isAfter(DateTime.now()))) {
        _finishFailedActivation(generation);
        return false;
      }

      _activeProfile = verifiedProfile;
      _snapshot = loaded;
      _sessionAccountId = accountId;

      _adultAccessToken = adultToken;
      _adultValidUntil = adultExpiry;

      _isLoading = false;
      _refreshing = false;

      if (adultExpiry != null) {
        _scheduleAdultExpiry(adultExpiry);
      }

      if (verifiedProfile.type ==
          FamilyProfileType.child) {
        _startChildRefresh();
      }

      _notify();

      return isReady;
    } catch (_) {
      _finishFailedActivation(generation);
      return false;
    }
  }

  bool _isCurrentRequest(
    int generation,
    String accountId,
  ) {
    return !_disposed &&
        generation == _generation &&
        _client.auth.currentUser?.id == accountId;
  }

  void _finishFailedActivation(int generation) {
    if (generation != _generation || _disposed) {
      return;
    }

    _stopChildRefresh();
    _cancelAdultExpiry();

    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;

    _isLoading = false;
    _refreshing = false;

    _notify();
  }

  /// Reloads permissions without extending the PIN session.
  ///
  /// Child profiles remain selected if Supabase is
  /// temporarily unreachable. However, all child content
  /// remains blocked until a successful refresh.
  Future<bool> refreshPermissions() async {
    if (_disposed || _refreshing || _isLoading) {
      return false;
    }

    final profile = activeProfile;
    final accountId = _sessionAccountId;

    if (profile == null || accountId == null) {
      clearSession();
      return false;
    }

    final adultToken = _adultAccessToken;
    final adultExpiry = _adultValidUntil;

    final generation = ++_generation;

    _refreshing = true;

    // Fail closed immediately while loading.
    _snapshot = null;

    _notify();

    try {
      if (profile.type ==
          FamilyProfileType.adult) {
        if (adultToken == null ||
            adultExpiry == null ||
            !adultExpiry.isAfter(DateTime.now())) {
          _finishFailedActivation(generation);
          return false;
        }

        final valid = await _pinService.checkSession(
          scope: FamilyPinScope.parent,
          accessToken: adultToken,
        );

        if (!_isCurrentRequest(generation, accountId)) {
          return false;
        }

        if (!valid ||
            !adultExpiry.isAfter(DateTime.now())) {
          _finishFailedActivation(generation);
          return false;
        }
      }

      final profiles =
          await _profileService.loadProfiles();

      if (!_isCurrentRequest(generation, accountId)) {
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

      // A deleted or changed profile cannot retain access.
      if (currentProfile == null ||
          currentProfile.type != profile.type) {
        _finishFailedActivation(generation);
        return false;
      }

      final loaded = await _accessService.loadSnapshot(
        profile: currentProfile,
      );

      if (!_isCurrentRequest(generation, accountId)) {
        return false;
      }

      if (!loaded.isReady ||
          loaded.profileId != currentProfile.id ||
          loaded.isChild !=
              (currentProfile.type ==
                  FamilyProfileType.child) ||
          (adultExpiry != null &&
              !adultExpiry.isAfter(DateTime.now()))) {
        return _handleRefreshFailure(
          generation,
          profile,
        );
      }

      _activeProfile = currentProfile;
      _snapshot = loaded;
      _sessionAccountId = accountId;

      _refreshing = false;
      _isLoading = false;

      _notify();

      return isReady;
    } catch (_) {
      return _handleRefreshFailure(
        generation,
        profile,
      );
    }
  }

  bool _handleRefreshFailure(
    int generation,
    FamilyProfile profile,
  ) {
    if (_disposed || generation != _generation) {
      return false;
    }

    // An adult authentication failure must not be
    // treated as a temporary child permission error.
    if (profile.type != FamilyProfileType.child) {
      _finishFailedActivation(generation);
      return false;
    }

    if (!_belongsToCurrentAccount ||
        _activeProfile?.id != profile.id) {
      _finishFailedActivation(generation);
      return false;
    }

    // Preserve the child profile selection but
    // revoke all cached content permissions.
    _snapshot = null;
    _refreshing = false;
    _isLoading = false;

    // The periodic timer remains active, so another
    // refresh can restore access when Supabase responds.
    _notify();

    return false;
  }

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

  void clearSession() {
    ++_generation;

    _stopChildRefresh();
    _cancelAdultExpiry();

    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;

    _isLoading = false;
    _refreshing = false;

    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;

    _stopChildRefresh();
    _cancelAdultExpiry();

    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();

    super.dispose();
  }
}

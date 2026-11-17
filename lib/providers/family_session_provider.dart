
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/watch_progress_service.dart';
import '../services/profile_sync_clock.dart';
import '../services/profile_preference_outbox.dart';
import '../services/profile_favorite_outbox.dart';
import '../services/profile_history_service.dart';

import '../models/family_profile.dart';
import '../services/family_content_access_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_service.dart';

/// Manages the active family profile for the signed-in account.
///
/// Adult profiles require a server-verified parent PIN session.
/// Child profiles do not require a PIN.
///
/// Child permissions must be successfully loaded before activation.
class FamilySessionProvider extends ChangeNotifier with WidgetsBindingObserver {
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

  final FamilyContentAccessService _accessService;
  final FamilyPinService _pinService;
  final FamilyProfileService _profileService;
  final SupabaseClient _client;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _profileSyncTimer;
  bool _profileSyncRunning = false;
  int _profileSyncRevision = 0;
  int get profileSyncRevision => _profileSyncRevision;
  bool _foreground = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _networkRetryTimer;
  bool _syncRequested = false;

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _networkRetryTimer?.cancel();
    if (_disposed || !_foreground || !isReady ||
        !results.any((result) => result != ConnectivityResult.none)) return;
    unawaited(_syncProfileCache());
    // A transport event can precede internet reachability (e.g. Wi-Fi DHCP).
    _networkRetryTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_syncProfileCache());
    });
  }

  void _stopProfileSync() {
    _profileSyncTimer?.cancel();
    _profileSyncTimer = null;
    _networkRetryTimer?.cancel();
    _networkRetryTimer = null;
    final subscription = _connectivitySubscription;
    _connectivitySubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _syncRequested = false;
  }

  void _startProfileSync() {
    _stopProfileSync();
    if (_disposed || !_foreground || !isReady) return;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stack) {
        // Periodic sync remains available if the platform stream fails.
      },
    );
    _profileSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_syncProfileCache());
    });
    unawaited(_syncProfileCache());
  }

  Future<void> _syncProfileCache() async {
    final profile = activeProfile;
    final generation = _generation;
    if (_disposed || !_foreground || !isReady || profile == null) return;
    if (_profileSyncRunning) {
      _syncRequested = true;
      return;
    }
    _profileSyncRunning = true;
    bool current() => !_disposed && _foreground && isReady &&
        generation == _generation && activeProfile?.id == profile.id;
    try {
      await ProfileSyncClock.calibrate(_client);
      if (!current()) return;
      await ProfileFavoriteOutbox.flush(_client, profile.accountUserId, profile.id, parentAccessToken, current);
      if (!current()) return;
      await ProfilePreferenceOutbox.flush(_client, profile.accountUserId, profile.id, parentAccessToken, current);
      if (!current()) return;
      // Adult display rules are personal preferences, not child permissions.
      if (profile.isAdult && !_refreshing) {
        final updated = await _accessService.loadSnapshot(
          profile: profile, parentToken: parentAccessToken,
        );
        if (!current()) return;
        if (!_refreshing && updated.isReady && updated.profileId == profile.id && !updated.isChild) {
          _snapshot = updated;
        }
      }
      await WatchProgressService(family: this, client: _client).flushPending();
      if (!current()) return;
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'streamia_history_v2:${profile.accountUserId}:${profile.id}:';
      for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        if (!current()) return;
        final source = key.substring(prefix.length);
        if (source.isNotEmpty) {
          await ProfileHistoryService(this, source, client: _client).refresh();
        }
      }
      if (current()) {
        _profileSyncRevision++;
        _notify();
      }
    } catch (_) { /* Retry during the next foreground cycle. */ }
    finally {
      _profileSyncRunning = false;
      if (_syncRequested) {
        _syncRequested = false;
        if (!_disposed && _foreground && isReady) {
          unawaited(_syncProfileCache());
        }
      }
    }
  }

  Timer? _adultExpiryTimer;
  Timer? _childRefreshTimer;
  static const _childRefreshInterval = Duration(seconds: 60);
  bool _refreshing = false;
  bool get isRefreshingPermissions => _refreshing;

  void _stopChildRefresh() {
    _childRefreshTimer?.cancel();
    _childRefreshTimer = null;
  }

  void _startChildRefresh() {
    _stopChildRefresh();
    if (_disposed || !isChild || !_belongsToCurrentAccount) return;
    _childRefreshTimer = Timer.periodic(_childRefreshInterval, (_) {
      if (!_disposed && !_refreshing && !_isLoading && isChild &&
          _belongsToCurrentAccount) {
        unawaited(refreshPermissions());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startProfileSync();
    } else {
      _stopProfileSync();
    }
    if (state == AppLifecycleState.resumed && !_disposed && isChild &&
        !_refreshing && !_isLoading && _belongsToCurrentAccount) {
      unawaited(refreshPermissions());
    }
  }


  FamilyProfile? _activeProfile;
  FamilyContentAccessSnapshot? _snapshot;
  String? _sessionAccountId;

  String? _adultAccessToken;
  DateTime? _adultValidUntil;

  bool _isLoading = false;
  bool _disposed = false;
  int _generation = 0;

  bool get _belongsToCurrentAccount {
    final currentAccountId =
        _client.auth.currentUser?.id;

    return currentAccountId != null &&
        _sessionAccountId == currentAccountId &&
        _activeProfile != null &&
        _activeProfile!.accountUserId ==
            currentAccountId;
  }

  bool get _adultSessionCurrent {
    if (_activeProfile?.type !=
        FamilyProfileType.adult) {
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

  /// A verified parent token is available only during an active adult session.
  String? get parentAccessToken => isAdult && isReady ? _adultAccessToken : null;

  bool get hasActiveProfile => activeProfile != null;
  bool get isLoading => _isLoading;

  bool get isChild =>
      activeProfile?.type == FamilyProfileType.child;

  bool get isAdult =>
      activeProfile?.type == FamilyProfileType.adult;

  bool get isReady =>
      !_isLoading &&
      _belongsToCurrentAccount &&
      _adultSessionCurrent &&
      _snapshot != null &&
      _snapshot!.profileId == _activeProfile!.id &&
      _snapshot!.isReady;

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

  void _scheduleAdultExpiry(DateTime expiry) {
    _adultExpiryTimer?.cancel();

    final remaining =
        expiry.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      clearSession();
      return;
    }

    _adultExpiryTimer =
        Timer(remaining, clearSession);
  }

  /// Activates a profile after checking account ownership.
  ///
  /// The existing adultPin argument is retained for compatibility
  /// with callers. Its value is now the PARENT PIN.
  Future<bool> activateProfile(
    FamilyProfile profile, {
    String? adultPin,
  }) async {
    final generation = ++_generation;

    _stopProfileSync();
    _stopChildRefresh();
    _cancelAdultExpiry();
    _refreshing = false;
    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;
    _isLoading = true;
    _notify();

    try {
      final accountId =
          _client.auth.currentUser?.id;

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

      String? adultToken;
      DateTime? adultExpiry;

      if (verifiedProfile.type ==
          FamilyProfileType.adult) {
        // The adult profile uses the account's parent PIN.
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

        if (generation != _generation ||
            _client.auth.currentUser?.id != accountId) {
          _finishFailedActivation(generation);
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

        // Verify the parent session with Supabase.
        final sessionValid =
            await _pinService.checkSession(
          scope: FamilyPinScope.parent,
          accessToken: adultToken!,
        );

        if (generation != _generation ||
            _client.auth.currentUser?.id != accountId ||
            !sessionValid ||
            !adultExpiry!.isAfter(DateTime.now())) {
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
        parentToken: adultToken,
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

      if (adultExpiry != null) {
        _scheduleAdultExpiry(adultExpiry);
      }
      if (verifiedProfile.type == FamilyProfileType.child) {
        _startChildRefresh();
      }

      _notify();
      if (_profileSyncTimer == null) _startProfileSync();
      return isReady;
    } catch (_) {
      _finishFailedActivation(generation);
      return false;
    }
  }

  void _finishFailedActivation(int generation) {
    if (generation != _generation) return;

    _stopProfileSync();
    _stopChildRefresh();
    _cancelAdultExpiry();
    _refreshing = false;
    _activeProfile = null;
    _snapshot = null;
    _sessionAccountId = null;
    _isLoading = false;
    _notify();
  }

  /// Refreshes permissions without interrupting valid playback while the
  /// request is pending. If the server rejects or cannot load permissions,
  /// the snapshot is revoked (fail closed). A subsequent successful refresh
  /// restores access without forcing the child to select the profile again.
  Future<bool> refreshPermissions() async {
    if (_disposed || _refreshing || _isLoading) return false;
    final profile = activeProfile;
    final accountId = _sessionAccountId;
    if (profile == null || accountId == null) {
      clearSession();
      return false;
    }
    final generation = _generation;
    _refreshing = true;
    // Keep the last validated snapshot during the network round trip.
    // A revoked category will be stopped as soon as the new result arrives.
    // On a network failure, revoke the snapshot to deny all child content.
    _notify();
    try {
      final adultToken = _adultAccessToken;
      final adultExpiry = _adultValidUntil;
      if (profile.type == FamilyProfileType.adult) {
        if (adultToken == null || adultExpiry == null ||
            !adultExpiry.isAfter(DateTime.now()) ||
            !await _pinService.checkSession(
              scope: FamilyPinScope.parent,
              accessToken: adultToken,
            )) {
          if (generation == _generation) clearSession();
          return false;
        }
      }
      final profiles = await _profileService.loadProfiles();
      if (!_refreshStillCurrent(generation, accountId, profile.id)) return false;
      FamilyProfile? currentProfile;
      for (final candidate in profiles) {
        if (candidate.id == profile.id && candidate.accountUserId == accountId) {
          currentProfile = candidate;
          break;
        }
      }
      if (currentProfile == null || currentProfile.type != profile.type) {
        clearSession();
        return false;
      }
      final loaded = await _accessService.loadSnapshot(profile: currentProfile, parentToken: adultToken);
      if (!_refreshStillCurrent(generation, accountId, profile.id)) return false;
      if (!loaded.isReady || loaded.profileId != currentProfile.id ||
          loaded.isChild != (currentProfile.type == FamilyProfileType.child)) {
        return _failRefresh(generation, profile);
      }
      _activeProfile = currentProfile;
      _snapshot = loaded;
      _refreshing = false;
      _notify();
      if (_profileSyncTimer == null) _startProfileSync();
      return isReady;
    } catch (_) {
      return _failRefresh(generation, profile);
    }
  }

  bool _refreshStillCurrent(int generation, String accountId, String profileId) =>
      !_disposed && generation == _generation &&
      _client.auth.currentUser?.id == accountId &&
      _activeProfile?.id == profileId;

  bool _failRefresh(int generation, FamilyProfile profile) {
    if (_disposed || generation != _generation) return false;
    if (profile.type != FamilyProfileType.child) {
      clearSession();
      return false;
    }
    // Keep the selected child profile but deny all playback and navigation.
    _snapshot = null;
    _refreshing = false;
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
    _stopProfileSync();
    _stopChildRefresh();
    _refreshing = false;
    _cancelAdultExpiry();

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
    _stopProfileSync();
    _stopChildRefresh();
    _refreshing = false;
    _cancelAdultExpiry();
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

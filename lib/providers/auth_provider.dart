import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../core/storage/prefs_service.dart';

class AuthProvider extends ChangeNotifier {
  static const MethodChannel _deviceChannel = MethodChannel('com.streamia/device_identity');
  static const String _installKey = 'streamia_installation_id';
  static const String _pendingEmailKey = 'streamia_pending_confirmation_email';
  static const String _redirectUrl = 'streamiaplayer://auth/callback';

  final PrefsService _prefs;
  StreamSubscription<AuthState>? _authSubscription;
  String? _installationId;
  String? _deviceId;
  String? _deviceStatus;
  Map<String, dynamic>? _access;
  bool _busy = false;
  bool _loadingDevices = false;
  String? _deviceListError;
  List<Map<String, dynamic>> _activeDevices = const [];
  bool _accessChecked = false;
  bool _checkingConfirmation = true;
  bool _emailConfirmationSuccess = false;
  String? _error;
  bool _registrationSubmitted = false;
  bool _registrationNeedsConfirmation = false;

  AuthProvider(this._prefs) {
    _installationId = _prefs.getString(_installKey);
    if (SupabaseConfig.isConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedOut) _clearAccess();
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.initialSession) {
          unawaited(_inspectConfirmationAndAccess());
        }
        notifyListeners();
      });
      unawaited(_inspectConfirmationAndAccess());
    } else {
      _checkingConfirmation = false;
    }
  }

  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;
  User? get user => _client?.auth.currentUser;
  bool get isLoggedIn => !_checkingConfirmation && !_emailConfirmationSuccess && user != null;
  bool get isBusy => _busy;
  bool get loadingDevices => _loadingDevices;
  String? get deviceListError => _deviceListError;
  List<Map<String, dynamic>> get activeDevices =>
      List.unmodifiable(_activeDevices);
  bool get accessChecked => _accessChecked;
  String? get error => _error;
  String? get deviceId => _deviceId;
  String? get deviceStatus => _deviceStatus;
  Map<String, dynamic>? get access => _access;
  bool get registrationSubmitted => _registrationSubmitted;
  bool get registrationNeedsConfirmation => _registrationNeedsConfirmation;
  bool get emailConfirmationSuccess => _emailConfirmationSuccess;
  String get macAddress => _installationId ?? 'Noch nicht registriert';
  bool get hasAccountAccess => _access?['has_access'] == true;
  bool get deviceApproved => _deviceStatus == 'active' || _deviceStatus == 'approved';
  bool get devicePending => _deviceStatus == 'pending';
  bool get deviceBlocked => _deviceStatus == 'blocked' || _deviceStatus == 'rejected' || _deviceStatus == 'revoked';
  bool get hasAccess => _accessChecked && _error == null && hasAccountAccess && deviceApproved;
  bool get requiresPayment => _accessChecked && _error == null && _access != null && !hasAccountAccess;
  String? get accessReason => _access?['access_reason']?.toString();
  int get maxDevices {
    final value = _access?['max_devices'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
  bool get isAdminGrant => _access?['manual_override'] == true && _access?['entitlement_source'] == 'admin_grant';

  // The confirmation is tied to the email registered on this installation.
  // Never treat an arbitrary sign-in as a confirmation without a confirmed email.
  Future<void> _inspectConfirmationAndAccess() async {
    final client = _client;
    if (client == null) return;
    _checkingConfirmation = true;
    notifyListeners();
    try {
      final current = client.auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final pendingEmail = prefs.getString(_pendingEmailKey);
      final isConfirmed = current?.emailConfirmedAt != null;
      final matchesPending = pendingEmail != null &&
          current?.email?.toLowerCase() == pendingEmail.toLowerCase();
      if (isConfirmed && matchesPending) {
        // Clear marker before sign-out to prevent reprocessing.
        await prefs.remove(_pendingEmailKey);
        await client.auth.signOut();
        _clearAccess();
        _emailConfirmationSuccess = true;
      } else if (current != null && !_emailConfirmationSuccess) {
        await refreshDeviceAndAccess();
      }
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _checkingConfirmation = false;
      notifyListeners();
    }
  }

  void dismissEmailConfirmationSuccess() {
    _emailConfirmationSuccess = false;
    notifyListeners();
  }

  void _clearAccess() {
    _deviceId = null;
    _deviceStatus = null;
    _activeDevices = const [];
    _deviceListError = null;
    _loadingDevices = false;
    _access = null;
    _accessChecked = false;
    _error = null;
  }

  // Android 8+: ANDROID_ID is scoped to app signing key, Android user and device.
  // It generally survives uninstall/reinstall with the SAME signing key.
  // It is not an IMEI, cannot be treated as unforgeable proof of hardware,
  // and may change after a factory reset, signing-key change or user switch.
  Future<String> _getInstallationId() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final id = (await _deviceChannel.invokeMethod<String>('getAndroidId'))
            ?.trim().toLowerCase();
        if (id != null && RegExp(r'^[0-9a-f]{16}$').hasMatch(id) &&
            id != '9774d56d682e549c' && id != '0000000000000000') {
          final stableId = 'android-v1-$id';
          _installationId = stableId;
          return stableId;
        }
      } on PlatformException catch (error) {
        debugPrint('Android device identity unavailable: ${error.code}');
      } on MissingPluginException {
        debugPrint('Android device identity channel unavailable');
      }
    }

    // For other platforms or devices without an accessible Android ID,
    // retain the existing installation-scoped random identifier.
    if (_installationId != null && _installationId!.isNotEmpty &&
        !_installationId!.startsWith('android-v1-')) {
      return _installationId!;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_installKey);
    if (saved != null && saved.isNotEmpty &&
        !saved.startsWith('android-v1-')) {
      _installationId = saved;
      return saved;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    _installationId = base64Url.encode(bytes).replaceAll('=', '');
    await prefs.setString(_installKey, _installationId!);
    return _installationId!;
  }

  Future<String> _readDeviceName() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final name = await _deviceChannel.invokeMethod<String>('getDeviceName');
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    return kIsWeb ? 'Web-Gerät' : defaultTargetPlatform.name;
  }

  Future<void> signIn(String email, String password) async {
    _registrationSubmitted = false;
    _registrationNeedsConfirmation = false;
    _emailConfirmationSuccess = false;
    await _run(() async {
      final client = _client;
      if (client == null) throw Exception('Supabase ist nicht konfiguriert.');
      _clearAccess();
      await client.auth.signInWithPassword(email: email.trim(), password: password);
      await refreshDeviceAndAccess();
    });
  }

  Future<void> signUp(String email, String password) async {
    _registrationSubmitted = false;
    _registrationNeedsConfirmation = false;
    _emailConfirmationSuccess = false;
    await _run(() async {
      final client = _client;
      if (client == null) throw Exception('Supabase ist nicht konfiguriert.');
      _clearAccess();
      final normalizedEmail = email.trim();
      final response = await client.auth.signUp(
        email: normalizedEmail,
        password: password,
        emailRedirectTo: _redirectUrl,
      );
      if (response.user == null && response.session == null) {
        throw const AuthException('Registration returned no user');
      }
      _registrationSubmitted = true;
      _registrationNeedsConfirmation = response.session == null;
      if (_registrationNeedsConfirmation) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingEmailKey, normalizedEmail.toLowerCase());
      }
      if (response.session != null) await refreshDeviceAndAccess();
    });
  }

  Future<void> refreshDeviceAndAccess() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      _clearAccess();
      notifyListeners();
      return;
    }
    _accessChecked = false;
    _error = null;
    _access = null;
    _deviceStatus = null;
    _activeDevices = const [];
    _deviceListError = null;
    notifyListeners();
    try {
      // Check account access before registering the device. The server is the
      // authority for trial eligibility, expiration, and administrative grants.
      final initialAccess = _firstRow(await client.rpc('get_my_access_status'));
      if (initialAccess == null) {
        throw StateError('Die Kontoberechtigung konnte nicht ermittelt werden.');
      }
      if (initialAccess['has_access'] != true) {
        // Existing server RPC: starts a trial only once. A rejected request
        // must never grant access locally or prevent an expired user from
        // reaching the normal payment screen.
        try {
          await client.rpc('start_streamia_trial');
        } on PostgrestException {
          // The server may reject repeat trials, expired trials, or other
          // ineligible accounts. Re-read authoritative access below.
        }
      }

      final installationId = await _getInstallationId();
      final deviceName = await _readDeviceName();
      final platform = kIsWeb ? 'web' : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => 'unknown',
      };
      final registered = await client.rpc('register_my_device', params: {
        'p_installation_id': installationId,
        'p_device_name': deviceName,
        'p_platform': platform,
      });
      final registrationRow = _firstRow(registered);
      if (registrationRow == null) throw Exception('Die Geräteregistrierung hat keine Daten zurückgegeben.');
      _deviceId = registrationRow['device_id']?.toString();
      _deviceStatus = registrationRow['device_status']?.toString().toLowerCase();
      final accountResult = await client.rpc('get_my_access_status');
      final accountRow = _firstRow(accountResult);
      if (accountRow == null) throw Exception('Die Kontoberechtigung konnte nicht ermittelt werden.');
      _access = accountRow;
      _accessChecked = true;
      _error = null;
    } catch (e) {
      _access = null;
      _accessChecked = true;
      _error = _friendlyError(e);
    }
    notifyListeners();
  }

  // Replace a previous active installation only after explicit user confirmation.
  // The server enforces account ownership, active entitlement, blocked-device
  // protection and a 24-hour cooldown. Trial timestamps are never changed.
  Future<void> replaceActiveDevice(String oldDeviceId) async {
    if (_busy) return;
    final client = _client;
    if (client == null || client.auth.currentUser == null ||
        !devicePending || !hasAccountAccess) {
      throw StateError('Gerätewechsel ist derzeit nicht möglich.');
    }
    _busy = true;
    _deviceListError = null;
    notifyListeners();
    try {
      final installationId = await _getInstallationId();
      final response = await client.rpc('replace_my_device_v2', params: {
        'p_old_device_id': oldDeviceId,
        'p_new_installation_id': installationId,
      });
      final row = _firstRow(response);
      if (row == null || row['device_status']?.toString() != 'active') {
        throw StateError('Der Server hat den Gerätewechsel nicht bestätigt.');
      }
      await refreshDeviceAndAccess();
      if (!hasAccess) {
        throw StateError('Gerätewechsel bestätigt, aber Zugriff noch nicht aktiv. Bitte erneut prüfen.');
      }
      _activeDevices = const [];
    } catch (e) {
      _deviceListError = _friendlyError(e);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> loadActiveDevices() async {
    if (_loadingDevices) return;
    final client = _client;
    if (client == null || client.auth.currentUser == null ||
        !devicePending || !hasAccountAccess) {
      _activeDevices = const [];
      _deviceListError = null;
      notifyListeners();
      return;
    }
    _loadingDevices = true;
    _deviceListError = null;
    notifyListeners();
    try {
      final result = await client.rpc('list_my_active_devices');
      if (result is! List) {
        throw StateError('Ungültige Antwort der Geräteverwaltung.');
      }
      _activeDevices = result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['device_id'] != null)
          .toList(growable: false);
    } catch (e) {
      _activeDevices = const [];
      _deviceListError = _friendlyError(e);
    } finally {
      _loadingDevices = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _firstRow(dynamic result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _registrationSubmitted = false;
      _registrationNeedsConfirmation = false;
      _error = _friendlyError(e);
      _accessChecked = true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') || message.contains('invalid credentials')) return 'invalid_credentials';
      if (message.contains('email not confirmed')) return 'email_not_confirmed';
      if (message.contains('too many requests') || message.contains('rate limit') || message.contains('over_email_send_rate_limit')) return 'too_many_requests';
      if (message.contains('invalid format') || message.contains('invalid email') || message.contains('unable to validate email')) return 'invalid_email';
      if (message.contains('already registered') || message.contains('already exists') || message.contains('user already registered')) return 'email_already_registered';
      if (message.contains('password') && (message.contains('weak') || message.contains('short') || message.contains('least'))) return 'weak_password';
      if (message.contains('registration returned no user')) return 'registration_failed';
      return 'auth_unavailable';
    }
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('once per 24 hours')) {
        return 'device_replacement_cooldown';
      }
      return 'device_request_failed';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> logout() async {
    await _client?.auth.signOut();
    _registrationSubmitted = false;
    _registrationNeedsConfirmation = false;
    _emailConfirmationSuccess = false;
    _clearAccess();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

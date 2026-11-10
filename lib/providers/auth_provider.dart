
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../core/storage/prefs_service.dart';

/// Supabase authentication and server-authoritative access.
///
/// Account access and device approval are separate checks.
/// A network or RPC error must never be treated as an
/// expired subscription.
class AuthProvider extends ChangeNotifier {
  static const MethodChannel _deviceChannel =
      MethodChannel('com.streamia/device_identity');

  static const String _installKey =
      'streamia_installation_id';

  final PrefsService _prefs;

  String? _installationId;
  String? _deviceId;
  String? _deviceStatus;

  Map<String, dynamic>? _access;

  bool _busy = false;
  bool _accessChecked = false;

  String? _error;

  AuthProvider(this._prefs) {
    _installationId = _prefs.getString(_installKey);

    if (SupabaseConfig.isConfigured) {
      Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
        if (event.event == AuthChangeEvent.signedOut) {
          _clearAccess();
        }
        notifyListeners();
      });

      Future<void>.microtask(() async {
        if (isLoggedIn) {
          await refreshDeviceAndAccess();
        }
      });
    }
  }

  SupabaseClient? get _client =>
      SupabaseConfig.isConfigured
          ? Supabase.instance.client
          : null;

  User? get user => _client?.auth.currentUser;

  bool get isLoggedIn => user != null;

  bool get isBusy => _busy;

  bool get accessChecked => _accessChecked;

  String? get error => _error;

  String? get deviceId => _deviceId;

  String? get deviceStatus => _deviceStatus;

  Map<String, dynamic>? get access => _access;

  String get macAddress =>
      _installationId ?? 'Noch nicht registriert';

  /// The account has a valid server-side entitlement.
  bool get hasAccountAccess =>
      _access?['has_access'] == true;

  /// The current device has been explicitly approved.
  bool get deviceApproved =>
      _deviceStatus == 'approved';

  bool get devicePending =>
      _deviceStatus == 'pending';

  bool get deviceBlocked =>
      _deviceStatus == 'blocked' ||
      _deviceStatus == 'rejected' ||
      _deviceStatus == 'revoked';

  /// Full access requires both account entitlement
  /// and an approved device.
  bool get hasAccess =>
      _accessChecked &&
      _error == null &&
      hasAccountAccess &&
      deviceApproved;

  /// Only a confirmed missing account entitlement
  /// may lead to the subscription page.
  bool get requiresPayment =>
      _accessChecked &&
      _error == null &&
      _access != null &&
      !hasAccountAccess;

  String? get accessReason =>
      _access?['access_reason']?.toString();

  int get maxDevices {
    final value = _access?['max_devices'];

    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get isAdminGrant =>
      _access?['manual_override'] == true &&
      _access?['entitlement_source'] == 'admin_grant';

  void _clearAccess() {
    _deviceId = null;
    _deviceStatus = null;
    _access = null;
    _accessChecked = false;
    _error = null;
  }

  Future<String> _getInstallationId() async {
    if (_installationId != null &&
        _installationId!.isNotEmpty) {
      return _installationId!;
    }

    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    _installationId =
        base64Url.encode(bytes).replaceAll('=', '');

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _installKey,
      _installationId!,
    );

    return _installationId!;
  }

  Future<String> _physicalFingerprint() async {
    String? nativeId;

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        nativeId = await _deviceChannel
            .invokeMethod<String>('getAndroidId');
      } catch (_) {
        // Fallback to the installation identifier.
      }
    }

    final source =
        nativeId != null && nativeId.isNotEmpty
            ? 'android:$nativeId'
            : 'installation:${await _getInstallationId()}';

    return sha256.convert(
      utf8.encode(source),
    ).toString();
  }

  Future<String> _readDeviceName() async {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        final name = await _deviceChannel
            .invokeMethod<String>('getDeviceName');

        if (name != null && name.isNotEmpty) {
          return name;
        }
      } catch (_) {
        // Use the platform fallback.
      }
    }

    return kIsWeb
        ? 'Web-Gerät'
        : defaultTargetPlatform.name;
  }

  Future<void> signIn(
    String email,
    String password,
  ) async {
    await _run(() async {
      final client = _client;

      if (client == null) {
        throw Exception(
          'Supabase ist nicht konfiguriert.',
        );
      }

      _clearAccess();

      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      await refreshDeviceAndAccess();
    });
  }

  Future<void> signUp(
    String email,
    String password,
  ) async {
    await _run(() async {
      final client = _client;

      if (client == null) {
        throw Exception(
          'Supabase ist nicht konfiguriert.',
        );
      }

      _clearAccess();

      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.session != null) {
        await refreshDeviceAndAccess();
      }
    });
  }

  /// Refresh account entitlement and device approval.
  ///
  /// Existing Supabase RPCs:
  /// - register_my_device
  /// - get_my_access_status
  /// - start_streamia_trial
  Future<void> refreshDeviceAndAccess() async {
    final client = _client;

    if (client == null ||
        client.auth.currentUser == null) {
      _clearAccess();
      notifyListeners();
      return;
    }

    _accessChecked = false;
    _error = null;
    _access = null;
    _deviceStatus = null;

    notifyListeners();

    try {
      final installationId =
          await _getInstallationId();

      // Retain the existing fingerprint helper for
      // future server-side device identity migration.
      // The current register_my_device RPC does not
      // accept a fingerprint parameter.
      await _physicalFingerprint();

      final deviceName =
          await _readDeviceName();

      final platform = kIsWeb
          ? 'web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'android',
              TargetPlatform.iOS => 'ios',
              _ => 'unknown',
            };

      final registered = await client.rpc(
        'register_my_device',
        params: {
          'p_installation_id': installationId,
          'p_device_name': deviceName,
          'p_platform': platform,
        },
      );

      final registrationRow =
          _firstRow(registered);

      if (registrationRow == null) {
        throw Exception(
          'Die Geräteregistrierung hat keine Daten zurückgegeben.',
        );
      }

      _deviceId =
          registrationRow['device_id']?.toString();

      _deviceStatus =
          registrationRow['device_status']?.toString();

      var accountResult = await client.rpc(
        'get_my_access_status',
      );

      var accountRow = _firstRow(accountResult);

      // Start an eligible account trial only if
      // no trial has already been started.
      //
      // Never call the trial RPC for admin grants
      // or existing paid subscriptions.
      if (accountRow != null &&
          accountRow['has_access'] != true &&
          accountRow['access_status'] == 'trial' &&
          accountRow['entitlement_source'] == 'trial' &&
          accountRow['trial_ends_at'] == null &&
          accountRow['manual_override'] != true) {
        await client.rpc('start_streamia_trial');

        accountResult = await client.rpc(
          'get_my_access_status',
        );

        accountRow = _firstRow(accountResult);
      }

      if (accountRow == null) {
        throw Exception(
          'Keine Kontoberechtigung gefunden. '
          'Bitte die Supabase-Berechtigungen prüfen.',
        );
      }

      _access = accountRow;
      _accessChecked = true;
      _error = null;
    } catch (e) {
      // A failed verification is not an expired trial.
      _access = null;
      _accessChecked = true;
      _error = _friendlyError(e);
    }

    notifyListeners();
  }

  Map<String, dynamic>? _firstRow(
    dynamic result,
  ) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return null;
  }

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    _busy = true;
    _error = null;

    notifyListeners();

    try {
      await action();
    } catch (e) {
      _error = _friendlyError(e);
      _accessChecked = true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    if (error is PostgrestException) {
      return error.message;
    }

    return error.toString().replaceFirst(
          'Exception: ',
          '',
        );
  }

  Future<void> logout() async {
    await _client?.auth.signOut();

    _clearAccess();

    notifyListeners();
  }
}

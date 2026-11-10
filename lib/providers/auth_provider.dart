
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../core/storage/prefs_service.dart';

/// Supabase authentication + server-authoritative per-device access.
/// A local identifier is only a fallback; the server owns all entitlement decisions.
class AuthProvider extends ChangeNotifier {
  static const MethodChannel _deviceChannel =
      MethodChannel('com.streamia/device_identity');
  static const _installKey = 'streamia_installation_id';

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
          .listen((_) => notifyListeners());
      Future<void>.microtask(() async {
        if (isLoggedIn) await refreshDeviceAndAccess();
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
  bool get hasAccess => _access?['has_access'] == true;
  String? get error => _error;
  String? get deviceId => _deviceId;
  String? get deviceStatus => _deviceStatus;
  Map<String, dynamic>? get access => _access;
  String get macAddress =>
      _installationId ?? 'Noch nicht registriert';

  Future<String> _getInstallationId() async {
    if (_installationId != null &&
        _installationId!.isNotEmpty) {
      return _installationId!;
    }

    final random = Random.secure();
    final bytes =
        List<int>.generate(32, (_) => random.nextInt(256));

    _installationId =
        base64Url.encode(bytes).replaceAll('=', '');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installKey, _installationId!);

    return _installationId!;
  }

  Future<String> _physicalFingerprint() async {
    String? nativeId;

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        nativeId = await _deviceChannel
            .invokeMethod<String>('getAndroidId');
      } catch (_) {}
    }

    // Never use a MAC address: modern Android does not expose
    // a reliable hardware MAC.
    final source =
        (nativeId != null && nativeId.isNotEmpty)
            ? 'android:$nativeId'
            : 'installation:${await _getInstallationId()}';

    return sha256.convert(utf8.encode(source)).toString();
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

      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.session != null) {
        await refreshDeviceAndAccess();
      }
    });
  }

  Future<void> refreshDeviceAndAccess() async {
    final client = _client;

    if (client == null ||
        client.auth.currentUser == null) {
      return;
    }

    final installationId =
        await _getInstallationId();

    final fingerprint =
        await _physicalFingerprint();

    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'unknown',
          };

    final deviceName = await _readDeviceName();

    final registered = await client.rpc(
      'register_my_device_v2',
      params: {
        'p_installation_id': installationId,
        'p_fingerprint_hash': fingerprint,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_legacy_installation_id': installationId,
      },
    );

    final row =
        registered is List && registered.isNotEmpty
            ? Map<String, dynamic>.from(
                registered.first as Map,
              )
            : Map<String, dynamic>.from(
                registered as Map,
              );

    _deviceId = row['device_id']?.toString();
    _deviceStatus =
        row['device_status']?.toString();

    final accessResult = await client.rpc(
      'get_my_device_access_status',
      params: {
        'p_installation_id':
            row['canonical_installation_id'] ??
                installationId,
      },
    );

    if (accessResult is List &&
        accessResult.isNotEmpty) {
      _access = Map<String, dynamic>.from(
        accessResult.first as Map,
      );
    } else if (accessResult is Map) {
      _access = Map<String, dynamic>.from(
        accessResult,
      );
    } else {
      _access = {
        'has_access': false,
        'access_reason': 'access_status_missing',
      };
    }

    _accessChecked = true;
    notifyListeners();
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
      } catch (_) {}
    }

    return kIsWeb
        ? 'Web-Gerät'
        : defaultTargetPlatform.name;
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

      if (isLoggedIn && !_accessChecked) {
        _access = {
          'has_access': false,
          'access_reason': 'verification_failed',
        };
        _accessChecked = true;
      }
    }

    _busy = false;
    notifyListeners();
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

    _deviceId = null;
    _deviceStatus = null;
    _access = null;
    _accessChecked = false;
    _error = null;

    notifyListeners();
  }
}

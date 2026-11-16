
import 'package:supabase_flutter/supabase_flutter.dart';

enum FamilyPinScope {
  parent,
  adult,
}

/// Result of checking whether the account
/// already has a configured parent PIN.
enum FamilyParentPinStatus {
  configured,
  notConfigured,
  unauthorized,
  unknown,
}

class FamilyPinVerification {
  final String status;
  final String? accessToken;
  final DateTime? validUntil;

  const FamilyPinVerification({
    required this.status,
    this.accessToken,
    this.validUntil,
  });

  bool get isSuccessful =>
      status == 'success' &&
      accessToken != null &&
      validUntil != null &&
      validUntil!.isAfter(DateTime.now());
}

class FamilyPinService {
  final SupabaseClient _client;

  FamilyPinService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _scopeValue(FamilyPinScope scope) {
    switch (scope) {
      case FamilyPinScope.parent:
        return 'parent';
      case FamilyPinScope.adult:
        return 'adult';
    }
  }

  void _validateScope({
    required FamilyPinScope scope,
    required String? familyProfileId,
  }) {
    if (scope == FamilyPinScope.parent &&
        familyProfileId != null) {
      throw ArgumentError(
        'Die Eltern-PIN darf keine Profil-ID enthalten.',
      );
    }

    if (scope == FamilyPinScope.adult &&
        (familyProfileId == null ||
            familyProfileId.isEmpty)) {
      throw ArgumentError(
        'Für die Erwachsenen-PIN ist eine Profil-ID erforderlich.',
      );
    }
  }

  /// Checks whether the authenticated account
  /// already has a parent PIN.
  ///
  /// The Supabase RPC returns only a status.
  /// No PIN, PIN hash or session token is exposed.
  ///
  /// A server error is not treated as
  /// "not configured".
  ///
  /// This prevents accidentally opening the
  /// initial PIN setup for existing accounts
  /// when the server is unavailable.
  Future<FamilyParentPinStatus>
      getParentPinStatus() async {
    if (_client.auth.currentUser == null) {
      return FamilyParentPinStatus.unauthorized;
    }

    final response = await _client.rpc(
      'get_family_parent_pin_status',
    );

    if (response is! String) {
      throw const FormatException(
        'Unerwartete Antwort bei der '
        'Eltern-PIN-Statusprüfung.',
      );
    }

    switch (response) {
      case 'configured':
        return FamilyParentPinStatus.configured;

      case 'not_configured':
        return FamilyParentPinStatus.notConfigured;

      case 'unauthorized':
        return FamilyParentPinStatus.unauthorized;

      default:
        return FamilyParentPinStatus.unknown;
    }
  }

  /// Initializes the parent PIN for the first time.
  ///
  /// Supabase allows this operation only if
  /// the authenticated account does not
  /// already have a parent PIN.
  ///
  /// An existing PIN cannot be overwritten
  /// or reset using this method.
  ///
  /// Valid PIN length: 6 to 12 digits.
  ///
  /// Possible results:
  /// - success
  /// - already_configured
  /// - invalid_pin
  /// - unauthorized
  ///
  /// Never log or locally store the PIN
  /// in plaintext.
  Future<String> initializeParentPin(
    String newPin,
  ) async {
    if (!RegExp(r'^[0-9]{6,12}$').hasMatch(newPin)) {
      return 'invalid_pin';
    }

    if (_client.auth.currentUser == null) {
      return 'unauthorized';
    }

    final response = await _client.rpc(
      'initialize_family_parent_pin',
      params: {
        'p_new_pin': newPin,
      },
    );

    if (response is! String) {
      throw const FormatException(
        'Unerwartete Antwort bei der '
        'Eltern-PIN-Einrichtung.',
      );
    }

    const allowedStatuses = {
      'success',
      'already_configured',
      'invalid_pin',
      'unauthorized',
    };

    if (!allowedStatuses.contains(response)) {
      throw FormatException(
        'Unbekannter Status bei der '
        'Eltern-PIN-Einrichtung: $response',
      );
    }

    return response;
  }

  /// Verifies a parent or adult PIN
  /// using the Supabase server.
  ///
  /// PINs and session tokens must never
  /// be written to logs or unprotected
  /// local preferences.
  Future<FamilyPinVerification> verifyPin({
    required FamilyPinScope scope,
    required String pin,
    String? familyProfileId,
  }) async {
    _validateScope(
      scope: scope,
      familyProfileId: familyProfileId,
    );

    if (!RegExp(r'^[0-9]{4,12}$').hasMatch(pin)) {
      return const FamilyPinVerification(
        status: 'invalid_pin',
      );
    }

    if (_client.auth.currentUser == null) {
      return const FamilyPinVerification(
        status: 'unauthorized',
      );
    }

    final response = await _client.rpc(
      'verify_family_pin',
      params: {
        'p_scope': _scopeValue(scope),
        'p_pin': pin,
        'p_family_profile_id': familyProfileId,
      },
    );

    if (response is! List || response.isEmpty) {
      throw const FormatException(
        'Unerwartete Antwort der PIN-Verifizierung.',
      );
    }

    final result = Map<String, dynamic>.from(
      response.first as Map,
    );

    final rawExpiry = result['valid_until'];

    return FamilyPinVerification(
      status:
          result['verification_status']?.toString() ??
              'unknown',
      accessToken:
          result['access_token']?.toString(),
      validUntil: rawExpiry == null
          ? null
          : DateTime.tryParse(rawExpiry.toString()),
    );
  }

  /// Checks whether an existing PIN session
  /// remains valid on the Supabase server.
  Future<bool> checkSession({
    required FamilyPinScope scope,
    required String accessToken,
    String? familyProfileId,
  }) async {
    _validateScope(
      scope: scope,
      familyProfileId: familyProfileId,
    );

    if (_client.auth.currentUser == null ||
        !RegExp(r'^[0-9a-f]{64}$')
            .hasMatch(accessToken)) {
      return false;
    }

    final response = await _client.rpc(
      'check_family_pin_session',
      params: {
        'p_token': accessToken,
        'p_scope': _scopeValue(scope),
        'p_family_profile_id': familyProfileId,
      },
    );

    return response == true;
  }
}

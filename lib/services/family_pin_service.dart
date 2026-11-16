
import 'package:supabase_flutter/supabase_flutter.dart';

/// The parent scope is used for:
/// - Unlocking adult profiles
/// - Family profile management
/// - Managing child category restrictions
///
/// The adult scope remains available for compatibility
/// with existing database functions and older app code.
enum FamilyPinScope {
  parent,
  adult,
}

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

  static final RegExp _newPinPattern =
      RegExp(r'^[0-9]{6,10}$');

  // Existing PINs may have been created under older
  // rules. Verification must not reject them locally
  // before the server can check them.
  static final RegExp _existingPinPattern =
      RegExp(r'^[0-9]{4,12}$');

  static final RegExp _tokenPattern =
      RegExp(r'^[0-9a-f]{64}$');

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

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
            familyProfileId.trim().isEmpty)) {
      throw ArgumentError(
        'Für die bisherige Erwachsenen-PIN '
        'ist eine Profil-ID erforderlich.',
      );
    }
  }

  bool _isValidNewPin(String pin) {
    return _newPinPattern.hasMatch(pin);
  }

  bool _isValidExistingPin(String pin) {
    return _existingPinPattern.hasMatch(pin);
  }

  bool _isValidToken(String token) {
    return _tokenPattern.hasMatch(token);
  }

  bool _isValidUuid(String value) {
    return _uuidPattern.hasMatch(value);
  }

  /// Checks whether the signed-in account already
  /// has a configured parent PIN.
  ///
  /// Server errors must never be interpreted
  /// as an unconfigured PIN.
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

  /// Creates the single account-level parent PIN.
  ///
  /// New PINs must contain 6–10 digits.
  ///
  /// An existing parent PIN is never overwritten.
  /// Supabase remains authoritative.
  Future<String> initializeParentPin(
    String newPin,
  ) async {
    if (!_isValidNewPin(newPin)) {
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

  /// Legacy compatibility only.
  ///
  /// The current family UI must not call this method.
  /// New adult profiles use the account-level parent PIN.
  ///
  /// This method is retained so older callers do not
  /// fail to compile during the migration.
  ///
  /// It does not change or remove any existing PIN.
  @Deprecated(
    'Separate adult PINs are no longer used. '
    'Use the account-level parent PIN.',
  )
  Future<String> initializeAdultPin({
    required String parentAccessToken,
    required String familyProfileId,
    required String newPin,
  }) async {
    if (_client.auth.currentUser == null) {
      return 'unauthorized';
    }

    if (!_isValidNewPin(newPin)) {
      return 'invalid_pin';
    }

    if (!_isValidUuid(familyProfileId)) {
      return 'invalid_profile';
    }

    if (!_isValidToken(parentAccessToken)) {
      return 'invalid_parent_session';
    }

    final response = await _client.rpc(
      'initialize_family_adult_pin',
      params: {
        'p_parent_token': parentAccessToken,
        'p_family_profile_id': familyProfileId,
        'p_new_pin': newPin,
      },
    );

    if (response is! String) {
      throw const FormatException(
        'Unerwartete Antwort bei der '
        'bisherigen Erwachsenen-PIN-Einrichtung.',
      );
    }

    const allowedStatuses = {
      'success',
      'already_configured',
      'invalid_pin',
      'invalid_profile',
      'invalid_parent_session',
      'unauthorized',
    };

    if (!allowedStatuses.contains(response)) {
      throw FormatException(
        'Unbekannter Status bei der '
        'Erwachsenen-PIN-Einrichtung: $response',
      );
    }

    return response;
  }

  /// Verifies a PIN using Supabase.
  ///
  /// Current adult profile activation must use:
  ///
  /// scope: FamilyPinScope.parent
  ///
  /// without a familyProfileId.
  ///
  /// Existing PIN lengths are accepted locally
  /// for backward compatibility. The server
  /// decides whether the PIN is correct.
  Future<FamilyPinVerification> verifyPin({
    required FamilyPinScope scope,
    required String pin,
    String? familyProfileId,
  }) async {
    _validateScope(
      scope: scope,
      familyProfileId: familyProfileId,
    );

    if (!_isValidExistingPin(pin)) {
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

    final first = response.first;

    if (first is! Map) {
      throw const FormatException(
        'Ungültiges Format der PIN-Verifizierung.',
      );
    }

    final result = Map<String, dynamic>.from(first);

    final status =
        result['verification_status']?.toString() ??
            'unknown';

    final token =
        result['access_token']?.toString();

    final rawExpiry = result['valid_until'];

    final expiry = rawExpiry == null
        ? null
        : DateTime.tryParse(rawExpiry.toString());

    // A failed verification must not expose
    // a token to the calling screen.
    if (status != 'success') {
      return FamilyPinVerification(
        status: status,
      );
    }

    if (token == null ||
        !_isValidToken(token) ||
        expiry == null ||
        !expiry.isAfter(DateTime.now())) {
      return const FamilyPinVerification(
        status: 'invalid_session',
      );
    }

    return FamilyPinVerification(
      status: 'success',
      accessToken: token,
      validUntil: expiry,
    );
  }

  /// Checks a PIN session on the Supabase server.
  ///
  /// A locally valid token format does not
  /// grant access by itself.
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
        !_isValidToken(accessToken)) {
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

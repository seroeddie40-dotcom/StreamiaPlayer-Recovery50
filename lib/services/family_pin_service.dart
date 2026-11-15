
import 'package:supabase_flutter/supabase_flutter.dart';

enum FamilyPinScope {
  parent,
  adult,
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

  /// Richtet die Eltern-PIN erstmalig ein.
  ///
  /// Supabase erlaubt diese Aktion nur, wenn für
  /// das angemeldete Konto noch keine Eltern-PIN
  /// existiert.
  ///
  /// Eine bestehende PIN kann über diese Methode
  /// weder geändert noch zurückgesetzt werden.
  ///
  /// Zulässige PIN-Länge: 6 bis 12 Ziffern.
  ///
  /// Rückgabewerte:
  /// - success
  /// - already_configured
  /// - invalid_pin
  /// - unauthorized
  ///
  /// Die PIN niemals protokollieren oder lokal
  /// im Klartext speichern.
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

  /// Verifiziert die PIN auf dem Supabase-Server.
  ///
  /// PIN und Sitzungstoken dürfen nicht in Logs
  /// oder ungeschützten Einstellungen gespeichert werden.
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
      status: result['verification_status']?.toString() ??
          'unknown',
      accessToken: result['access_token']?.toString(),
      validUntil: rawExpiry == null
          ? null
          : DateTime.tryParse(rawExpiry.toString()),
    );
  }

  /// Prüft, ob eine bestehende PIN-Sitzung
  /// auf dem Server weiterhin gültig ist.
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
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(accessToken)) {
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

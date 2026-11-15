
enum FamilyProfileType {
  adult,
  child,
}

class FamilyProfile {
  final String id;
  final String accountUserId;
  final String displayName;
  final String? avatarKey;
  final FamilyProfileType type;
  final bool isDefault;
  final int sortOrder;

  const FamilyProfile({
    required this.id,
    required this.accountUserId,
    required this.displayName,
    required this.avatarKey,
    required this.type,
    required this.isDefault,
    required this.sortOrder,
  });

  bool get isAdult => type == FamilyProfileType.adult;
  bool get isChild => type == FamilyProfileType.child;

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    final typeValue = json['profile_type']?.toString();

    if (typeValue != 'adult' && typeValue != 'child') {
      throw const FormatException(
        'Unbekannter Familienprofiltyp.',
      );
    }

    return FamilyProfile(
      id: json['id'] as String,
      accountUserId: json['account_user_id'] as String,
      displayName: json['display_name'] as String,
      avatarKey: json['avatar_key'] as String?,
      type: typeValue == 'child'
          ? FamilyProfileType.child
          : FamilyProfileType.adult,
      isDefault: json['is_default'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

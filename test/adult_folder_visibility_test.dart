import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamia_player/models/family_profile.dart';
import 'package:streamia_player/services/adult_folder_visibility_service.dart';
import 'package:streamia_player/services/family_content_access_service.dart';

FamilyProfile profile(String id, {bool child = false}) => FamilyProfile(id: id, accountUserId: 'account', displayName: id, avatarKey: null, type: child ? FamilyProfileType.child : FamilyProfileType.adult, isDefault: false, sortOrder: 0);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preferences are isolated and reversible', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AdultFolderVisibilityService();
    final adult = profile('a');
    expect(await service.load(adult), isEmpty);
    await service.setVisibility(profile: adult, sourceKey: 'playlist', contentType: 'vod', categoryKeys: ['17', '18'], visible: false);
    expect(await service.load(profile('b')), isEmpty);
    await expectLater(service.load(profile('c', child: true)), throwsArgumentError);
    final access = FamilyContentAccessSnapshot.forTesting(profileId: 'a', isChild: false, rulesLoaded: true, rules: [], adultHiddenRules: await service.load(adult));
    expect(access.filterItems<String>(items: ['17', '18', '19', ''], sourceKey: 'playlist', contentType: 'vod', categoryKeyOf: (e) => e), ['19', '']);
    expect(access.canAccessCategory(sourceKey: 'other', contentType: 'vod', categoryKey: '17'), isTrue);
    expect(access.canAccessCategory(sourceKey: 'playlist', contentType: 'live', categoryKey: '17'), isTrue);
    await service.setVisibility(profile: adult, sourceKey: 'playlist', contentType: 'vod', categoryKeys: ['17'], visible: true);
    expect((await service.load(adult)).single['category_key'], '18');
  });
}

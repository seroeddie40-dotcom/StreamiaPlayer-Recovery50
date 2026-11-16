import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/services/family_content_access_service.dart';

void main() {
  const source = 'xtream:account-a';
  const category = '17';
  const contentType = 'vod';

  Map<String, dynamic> rule({
    String sourceKey = source,
    String type = contentType,
    String key = category,
    bool visible = false,
  }) => {
    'source_key': sourceKey,
    'content_type': type,
    'category_key': key,
    'is_visible': visible,
  };

  FamilyContentAccessSnapshot snapshot({
    bool isChild = true,
    bool loaded = true,
    List<Map<String, dynamic>> rules = const [],
  }) => FamilyContentAccessSnapshot.forTesting(
    profileId: 'child-a',
    isChild: isChild,
    rulesLoaded: loaded,
    rules: rules,
  );

  bool allowed(FamilyContentAccessSnapshot access, {
    String sourceKey = source,
    String type = contentType,
    String key = category,
  }) => access.canAccessCategory(
    sourceKey: sourceKey,
    contentType: type,
    categoryKey: key,
  );

  test('children see every valid category by default', () {
    final access = snapshot();
    expect(allowed(access), isTrue);
    expect(allowed(access, key: '18'), isTrue);
    expect(allowed(access, type: 'live'), isTrue);
    expect(allowed(access, type: 'series'), isTrue);
  });

  test('only the exact explicitly blocked category is denied', () {
    final access = snapshot(rules: [rule()]);
    expect(allowed(access), isFalse);
    expect(allowed(access, key: '18'), isTrue);
    expect(allowed(access, type: 'series'), isTrue);
    expect(allowed(access, sourceKey: 'xtream:account-b'), isTrue);
  });

  test('explicitly visible rule grants category access', () {
    expect(allowed(snapshot(rules: [rule(visible: true)])), isTrue);
  });

  test('unloaded rules deny child access and filter out all items', () {
    final access = snapshot(loaded: false);
    expect(allowed(access), isFalse);
    expect(access.filterItems<String>(
      items: ['17', '18'], sourceKey: source, contentType: contentType,
      categoryKeyOf: (key) => key,
    ), isEmpty);
  });

  test('child content without original category ID is denied consistently', () {
    final access = snapshot();
    expect(allowed(access, key: ''), isFalse);
    expect(access.filterItems<String>(
      items: ['17', '', '18'], sourceKey: source, contentType: contentType,
      categoryKeyOf: (key) => key,
    ), ['17', '18']);
  });

  test('filtering matches direct access decisions across content types', () {
    final access = snapshot(rules: [rule(), rule(type: 'live', key: '9')]);
    expect(access.filterItems<String>(
      items: ['17', '18'], sourceKey: source, contentType: contentType,
      categoryKeyOf: (key) => key,
    ), ['18']);
    expect(access.filterItems<String>(
      items: ['9', '10'], sourceKey: source, contentType: 'live',
      categoryKeyOf: (key) => key,
    ), ['10']);
  });

  test('adult retains access to uncategorized entries', () {
    final access = snapshot(isChild: false, rules: [rule()]);
    expect(allowed(access, key: ''), isTrue);
    expect(access.filterItems<String>(
      items: ['17', ''], sourceKey: source, contentType: contentType,
      categoryKeyOf: (key) => key,
    ), ['17', '']);
  });

  test('unknown content types and empty source keys are denied to children', () {
    final access = snapshot();
    expect(allowed(access, type: 'download'), isFalse);
    expect(allowed(access, sourceKey: ''), isFalse);
  });
}

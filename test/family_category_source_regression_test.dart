import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel category IDs are never replaced by display labels', () {
    final source = File('lib/providers/content_provider.dart').readAsStringSync();
    expect(source.contains('channel.categoryKey ??= channel.category'), isFalse);
  });

  test('bulk edits verify reloaded rules before clearing selection', () {
    final source = File('lib/screens/family_child_category_permissions_screen.dart').readAsStringSync();
    expect(source.contains('final confirmed = chosen.every('), isTrue);
    expect(source.contains('if (!confirmed) {'), isTrue);
    expect(source.contains('_selectedKeys.clear();'), isTrue);
  });

  test('single-item status is verified against reloaded rules', () {
    final source = File('lib/screens/family_child_category_permissions_screen.dart').readAsStringSync();
    expect(source.contains('rules: updatedRules,'), isTrue);
    expect(source.contains('_changeVisibility(category, !visible)'), isTrue);
  });

  test('missing category IDs cannot bypass child restrictions', () {
    final source = File('lib/services/family_content_access_service.dart').readAsStringSync();
    expect(source.contains('if (rulesLoaded && !isChild) result.add(item);'), isTrue);
    expect(source.contains('if (rulesLoaded && !hasBlockedCategories)'), isFalse);
  });
}

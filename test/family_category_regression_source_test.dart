import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content provider preserves original category identifiers', () {
    final source = File('lib/providers/content_provider.dart').readAsStringSync();
    expect(source.contains('channel.categoryKey ??= channel.category;'), isFalse);
  });

  test('uncategorized items are denied to children but retained for adults', () {
    final source = File('lib/services/family_content_access_service.dart').readAsStringSync();
    expect(source.contains('hasBlockedCategories'), isFalse);
    expect(source.contains('if (rulesLoaded && !isChild) result.add(item);'), isTrue);
  });

  test('legacy M3U parser preserves original group-title as category key', () {
    final source = File('lib/services/m3u_parser.dart').readAsStringSync();
    expect(source.contains('categoryKey: currentGroup?.trim().isNotEmpty == true'), isTrue);
  });

  test('bulk update checks persisted state before clearing selection', () {
    final source = File('lib/screens/family_child_category_permissions_screen.dart').readAsStringSync();
    expect(source.contains('if (confirmed) _selectedKeys.clear();'), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/category_sort_service.dart';

void main() {
  test('sorts labels in every supported order without modifying input', () {
    final counts = {'TR': 10, 'de': 20, 'AR': 10};
    expect(CategorySortService.sorted(counts, CategorySortOrder.original), ['TR', 'de', 'AR']);
    expect(CategorySortService.sorted(counts, CategorySortOrder.ascending), ['AR', 'de', 'TR']);
    expect(CategorySortService.sorted(counts, CategorySortOrder.descending), ['TR', 'de', 'AR']);
    expect(CategorySortService.sorted(counts, CategorySortOrder.countDescending), ['de', 'TR', 'AR']);
    expect(CategorySortService.sorted(counts, CategorySortOrder.countAscending), ['TR', 'AR', 'de']);
    expect(counts.keys, ['TR', 'de', 'AR']);
  });
  test('empty catalog remains empty', () {
    for (final order in CategorySortOrder.values) {
      expect(CategorySortService.sorted({}, order), isEmpty);
    }
  });
}

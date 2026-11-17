/// Sorts display labels without changing the source catalog or category IDs.
enum CategorySortOrder { original, ascending, descending, countDescending, countAscending }

class CategorySortService {
  static List<String> sorted(Map<String, int> counts, CategorySortOrder order) {
    final labels = counts.keys.toList();
    if (order == CategorySortOrder.original) return labels;
    final positions = <String, int>{for (var i = 0; i < labels.length; i++) labels[i]: i};
    labels.sort((a, b) {
      final alphabetical = a.toLowerCase().compareTo(b.toLowerCase());
      int result;
      switch (order) {
        case CategorySortOrder.original:
          result = 0;
          break;
        case CategorySortOrder.ascending:
          result = alphabetical;
          break;
        case CategorySortOrder.descending:
          result = -alphabetical;
          break;
        case CategorySortOrder.countDescending:
          result = counts[b]!.compareTo(counts[a]!);
          break;
        case CategorySortOrder.countAscending:
          result = counts[a]!.compareTo(counts[b]!);
          break;
      }
      return result == 0 ? positions[a]!.compareTo(positions[b]!) : result;
    });
    return labels;
  }
}

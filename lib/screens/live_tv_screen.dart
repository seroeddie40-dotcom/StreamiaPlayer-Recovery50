import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/theme/app_theme.dart';
import '../models/channel.dart';
import '../providers/content_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/favorite_toggle_button.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  static const String _allCategory = '__streamia_all__';
  static const String _otherCategory = '__streamia_other__';

  String _selectedCategory = _allCategory;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(String de, String tr, String en) {
    final language = context.watch<LocaleProvider>().locale.languageCode;
    switch (language) {
      case 'de':
        return de;
      case 'tr':
        return tr;
      default:
        return en;
    }
  }

  String _categoryFor(Channel channel) {
    final category = channel.category?.trim();
    return category == null || category.isEmpty
        ? _otherCategory
        : category;
  }

  List<String> _categories(List<Channel> channels) {
    final names = channels
        .map(_categoryFor)
        .where((name) => name != _otherCategory)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (channels.any((channel) => _categoryFor(channel) == _otherCategory)) {
      names.add(_otherCategory);
    }
    return <String>[_allCategory, ...names];
  }

  String _categoryLabel(String category) {
    if (category == _allCategory) {
      return _text('Alle Sender', 'Tüm kanallar', 'All channels');
    }
    if (category == _otherCategory) {
      return _text('Ohne Kategorie', 'Kategorisiz', 'Uncategorized');
    }
    return category;
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  Widget _categoryPanel(
    List<Channel> channels,
    List<String> categories, {
    required bool inDrawer,
  }) {
    final countByCategory = <String, int>{};
    for (final channel in channels) {
      final category = _categoryFor(channel);
      countByCategory[category] = (countByCategory[category] ?? 0) + 1;
    }

    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              _text('Kategorien', 'Kategoriler', 'Categories'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = _selectedCategory == category;
                final count = category == _allCategory
                    ? channels.length
                    : countByCategory[category] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: selected
                        ? AppTheme.electricBlue.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      autofocus: !inDrawer && index == 0,
                      borderRadius: BorderRadius.circular(12),
                      focusColor:
                          AppTheme.electricBlue.withValues(alpha: 0.30),
                      onTap: () {
                        _selectCategory(category);
                        if (inDrawer) Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              category == _allCategory
                                  ? Icons.live_tv_rounded
                                  : Icons.folder_outlined,
                              color: selected
                                  ? AppTheme.electricBlue
                                  : Theme.of(context).iconTheme.color,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _categoryLabel(category),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$count',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = context.watch<ContentProvider>().channels;
    final categories = _categories(channels);
    final effectiveCategory = categories.contains(_selectedCategory)
        ? _selectedCategory
        : _allCategory;
    final search = _search.trim().toLowerCase();
    final filtered = channels.where((channel) {
      final categoryMatches = effectiveCategory == _allCategory ||
          _categoryFor(channel) == effectiveCategory;
      return categoryMatches &&
          (search.isEmpty || channel.name.toLowerCase().contains(search));
    }).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: _text('Zurück', 'Geri', 'Back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(_text('Live-TV', 'Canlı TV', 'Live TV')),
            actions: [
              if (compact)
                Builder(
                  builder: (scaffoldContext) => IconButton(
                    tooltip: _text('Kategorien', 'Kategoriler', 'Categories'),
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () =>
                        Scaffold.of(scaffoldContext).openEndDrawer(),
                  ),
                ),
            ],
          ),
          endDrawer: compact
              ? Drawer(
                  child: SafeArea(
                    child: _categoryPanel(
                      channels,
                      categories,
                      inDrawer: true,
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                SizedBox(
                  width: constraints.maxWidth >= 1100 ? 280 : 235,
                  child: _categoryPanel(
                    channels,
                    categories,
                    inDrawer: false,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 20,
                        14,
                        compact ? 12 : 20,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Builder(
                                builder: (drawerContext) => OutlinedButton.icon(
                                  onPressed: () => Scaffold.of(drawerContext).openEndDrawer(),
                                  icon: const Icon(Icons.category_outlined),
                                  label: Text(_categoryLabel(effectiveCategory)),
                                ),
                              ),
                            ),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _search = value),
                            textCapitalization: TextCapitalization.none,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: _text('Sender suchen', 'Kanal ara', 'Search channels'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              suffixIcon: search.isNotEmpty
                                  ? IconButton(
                                      tooltip: _text('Löschen', 'Temizle', 'Clear'),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_categoryLabel(effectiveCategory)} · ${filtered.length}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                channels.isEmpty
                                    ? _text('Keine Sender vorhanden', 'Kanal bulunamadı', 'No channels available')
                                    : _text('Keine passenden Sender', 'Eşleşen kanal yok', 'No matching channels'),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, area) {
                                final columns = area.maxWidth >= 950
                                    ? 5
                                    : area.maxWidth >= 700
                                        ? 4
                                        : area.maxWidth >= 450
                                            ? 3
                                            : 2;
                                return FocusTraversalGroup(
                                  child: GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.28,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) => _ChannelTile(
                                      channel: filtered[index],
                                      autofocus: compact && index == 0,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool autofocus;

  const _ChannelTile({required this.channel, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = channel.logoUrl?.trim();
    return InkWell(
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(16),
      focusColor: AppTheme.electricBlue.withValues(alpha: 0.22),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(channel: channel, isLive: true),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.electricBlue.withValues(alpha: 0.20),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: logo != null && logo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: logo,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.tv_rounded,
                                size: 40,
                              ),
                            )
                          : const Icon(Icons.tv_rounded, size: 40),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Text(
                    channel.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 2,
              right: 2,
              child: FavoriteToggleButton(
                contentId: channel.id,
                contentType: 'live',
                title: channel.name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

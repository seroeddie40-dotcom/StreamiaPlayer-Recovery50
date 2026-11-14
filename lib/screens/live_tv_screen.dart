
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/theme/app_theme.dart';
import '../models/channel.dart';
import '../providers/content_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/favorite_toggle_button.dart';
import '../widgets/voice_input_field.dart';
import 'player_screen.dart';

/// Live-TV catalogue for phones, tablets and Android TV.
class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  static const _all = '__streamia_all__';
  static const _other = '__streamia_other__';

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  String _selectedCategory = _all;
  bool _folderFocusExpanded = false;
  String _search = '';

  List<Channel>? _cachedChannels;
  List<String> _cachedCategories = const [];
  Map<String, int> _cachedCounts = const {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;

    final next = _searchController.text.trim().toLowerCase();

    if (next != _search) {
      setState(() => _search = next);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _text(String de, String tr, String en) {
    final code = context.read<LocaleProvider>().locale.languageCode;

    switch (code) {
      case 'de':
        return de;
      case 'tr':
        return tr;
      default:
        return en;
    }
  }

  String _categoryFor(Channel channel) {
    final value = channel.category?.trim();

    return value == null || value.isEmpty ? _other : value;
  }

  void _updateCategories(List<Channel> channels) {
    if (identical(channels, _cachedChannels)) return;

    final counts = <String, int>{};

    for (final channel in channels) {
      final category = _categoryFor(channel);
      counts[category] = (counts[category] ?? 0) + 1;
    }

    final categories = counts.keys
        .where((key) => key != _other)
        .toList()
      ..sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

    if (counts.containsKey(_other)) {
      categories.add(_other);
    }

    _cachedChannels = channels;
    _cachedCounts = counts;
    _cachedCategories = <String>[_all, ...categories];
  }

  String _label(String category) {
    if (category == _all) {
      return _text(
        'Alle Sender',
        'Tüm kanallar',
        'All channels',
      );
    }

    if (category == _other) {
      return _text(
        'Ohne Kategorie',
        'Kategorisiz',
        'Uncategorized',
      );
    }

    return category;
  }

  void _selectCategory(String category) {
    if (_selectedCategory != category) {
      setState(() => _selectedCategory = category);
    }
  }

  Widget _categoryPanel(
    List<Channel> channels, {
    required bool inDrawer,
  }) {
    final colors = Theme.of(context);

    return ColoredBox(
      color: colors.brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              _text(
                'Kategorien',
                'Kategoriler',
                'Categories',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: colors.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              itemCount: _cachedCategories.length,
              itemBuilder: (context, index) {
                final category = _cachedCategories[index];
                final selected = _selectedCategory == category;

                final count = category == _all
                    ? channels.length
                    : (_cachedCounts[category] ?? 0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected
                        ? AppTheme.electricBlue.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      focusColor:
                          AppTheme.electricBlue.withValues(alpha: 0.25),
                      onTap: () {
                        _selectCategory(category);

                        if (inDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              category == _all
                                  ? Icons.live_tv_rounded
                                  : Icons.folder_outlined,
                              size: 18,
                              color: selected
                                  ? AppTheme.electricBlue
                                  : null,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Tooltip(
                                message: _label(category),
                                child: Text(
                                  _label(category),
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$count',
                              style: colors.textTheme.labelSmall,
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

    _updateCategories(channels);

    final category = _cachedCategories.contains(_selectedCategory)
        ? _selectedCategory
        : _all;

    final filtered = <Channel>[];

    for (final channel in channels) {
      if (category != _all &&
          _categoryFor(channel) != category) {
        continue;
      }

      if (_search.isNotEmpty &&
          !channel.name.toLowerCase().contains(_search)) {
        continue;
      }

      filtered.add(channel);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        final language = context
            .watch<LocaleProvider>()
            .locale
            .languageCode;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: IconButton(
              tooltip: _text('Zurück', 'Geri', 'Back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  Navigator.of(context).maybePop(),
            ),
            title: Text(
              _text('Live-TV', 'Canlı TV', 'Live TV'),
            ),
            actions: compact
                ? [
                    Builder(
                      builder: (buttonContext) => IconButton(
                        tooltip: _text(
                          'Kategorien',
                          'Kategoriler',
                          'Categories',
                        ),
                        icon: const Icon(
                          Icons.folder_open_outlined,
                        ),
                        onPressed: () =>
                            Scaffold.of(buttonContext).openEndDrawer(),
                      ),
                    ),
                  ]
                : null,
          ),
          endDrawer: compact
              ? Drawer(
                  child: SafeArea(
                    child: _categoryPanel(
                      channels,
                      inDrawer: true,
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: _folderFocusExpanded
                      ? (constraints.maxWidth * 0.46)
                          .clamp(285.0, 480.0)
                      : (constraints.maxWidth >= 1100
                          ? 340.0
                          : 285.0),
                  child: Focus(
                    onFocusChange: (focused) {
                      if (mounted &&
                          focused != _folderFocusExpanded) {
                        setState(
                          () => _folderFocusExpanded = focused,
                        );
                      }
                    },
                    child: _categoryPanel(
                      channels,
                      inDrawer: false,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        4,
                      ),
                      child: Row(
                        children: [
                          if (compact) ...[
                            Builder(
                              builder: (buttonContext) =>
                                  IconButton(
                                tooltip: _label(category),
                                icon: const Icon(
                                  Icons.folder_open_outlined,
                                ),
                                onPressed: () =>
                                    Scaffold.of(buttonContext)
                                        .openEndDrawer(),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: VoiceInputField(
                                controller: _searchController,
                                appLanguageCode: language,
                                focusNode: _searchFocus,
                                keyboardType: TextInputType.text,
                                textInputAction:
                                    TextInputAction.search,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 10,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  hintText: _text(
                                    'Sender suchen',
                                    'Kanal ara',
                                    'Search channels',
                                  ),
                                  hintMaxLines: 1,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  suffixIcon: _search.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: _text(
                                            'Löschen',
                                            'Temizle',
                                            'Clear',
                                          ),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                          onPressed:
                                              _searchController.clear,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        2,
                        12,
                        6,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_label(category)} · ${filtered.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium,
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                channels.isEmpty
                                    ? _text(
                                        'Keine Sender vorhanden',
                                        'Kanal bulunamadı',
                                        'No channels available',
                                      )
                                    : _text(
                                        'Keine passenden Sender',
                                        'Eşleşen kanal yok',
                                        'No matching channels',
                                      ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, area) {
                                final width = area.maxWidth;

                                final columns = width >= 1000
                                    ? 6
                                    : width >= 760
                                        ? 5
                                        : width >= 520
                                            ? 4
                                            : width >= 330
                                                ? 3
                                                : 2;

                                return FocusTraversalGroup(
                                  child: GridView.builder(
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                      10,
                                      4,
                                      10,
                                      16,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      mainAxisExtent:
                                          width < 520 ? 118 : 136,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) =>
                                        _ChannelTile(
                                      channel: filtered[index],
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

  const _ChannelTile({
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final logo = channel.logoUrl?.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      focusColor:
          AppTheme.electricBlue.withValues(alpha: 0.22),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: channel,
            isLive: true,
          ),
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.electricBlue.withValues(alpha: 0.22),
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      8,
                      8,
                      8,
                      2,
                    ),
                    child: Center(
                      child: logo != null && logo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: logo,
                              fit: BoxFit.contain,
                              memCacheWidth: 240,
                              memCacheHeight: 150,
                              errorWidget: (_, __, ___) =>
                                  const Icon(
                                Icons.tv_rounded,
                                size: 30,
                              ),
                            )
                          : const Icon(
                              Icons.tv_rounded,
                              size: 30,
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 39,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      7,
                      1,
                      7,
                      5,
                    ),
                    child: Center(
                      child: Text(
                        channel.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
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

import '../widgets/profile_clock.dart';
import '../widgets/category_sort_control.dart';
import '../widgets/favorites_quick_filter.dart';
import '../services/category_sort_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/platform/device_layout.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../models/channel.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import '../services/family_content_access_service.dart';
import '../providers/locale_provider.dart';
import '../widgets/favorite_toggle_button.dart';
import '../widgets/voice_input_field.dart';
import 'player_screen.dart';

/// Compact, keyboard-safe Live TV catalogue for phones, tablets and Android TV.
class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> with CategorySortState<LiveTvScreen>, FavoritesQuickFilter<LiveTvScreen> {
  @override
  String get sortArea => 'live';
  static const _all = '__streamia_all__';
  static const _other = '__streamia_other__';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _selectedCategory = _all;
  bool _folderFocusExpanded = false;
  String _search = '';

  List<String> _cachedCategories = const [];
  Map<String, int> _cachedCounts = const {};
  Map<String, List<Channel>> _channelsByCategory = const {};
  List<Channel> _visibleChannels = const [];
  List<Channel>? _indexedSourceChannels;
  FamilyContentAccessSnapshot? _indexedPermissions;
  String? _indexedSourceKey;
  CategorySortOrder? _indexedSortOrder;
  bool _indexedReady = false;
  // Reuse the filtered catalogue across focus, clock and unrelated UI rebuilds.
  // Favorites are intentionally not cached: membership updates asynchronously.
  List<Channel>? _filteredSource;
  String? _filteredCategory;
  String? _filteredSearch;
  List<Channel> _filteredChannels = const [];

  List<Channel> _channelsForView(List<Channel> channels, String category) {
    if (!favoritesOnly &&
        identical(channels, _filteredSource) &&
        category == _filteredCategory &&
        _search == _filteredSearch) {
      return _filteredChannels;
    }
    // Use the category index instead of scanning the entire catalogue on
    // every folder change. Favorites still use their live membership check.
    final candidates = category == _all || favoritesOnly
        ? channels
        : (_channelsByCategory[category] ?? const <Channel>[]);
    final result = <Channel>[];
    for (final channel in candidates) {
      if (!matchesFavorite(channel.id)) continue;
      if (!favoritesOnly && category != _all && _categoryFor(channel) != category) continue;
      if (_search.isNotEmpty && !channel.name.toLowerCase().contains(_search)) continue;
      result.add(channel);
    }
    if (!favoritesOnly) {
      _filteredSource = channels;
      _filteredCategory = category;
      _filteredSearch = _search;
      _filteredChannels = List<Channel>.unmodifiable(result);
      return _filteredChannels;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final next = _searchController.text.trim().toLowerCase();
    if (next != _search) setState(() => _search = next);
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
      case 'de': return de;
      case 'tr': return tr;
      default: return en;
    }
  }

  String _categoryFor(Channel channel) {
    final value = channel.category?.trim();
    return value == null || value.isEmpty ? _other : value;
  }

  void _updateCategories(List<Channel> channels) {
    final grouped = <String, List<Channel>>{};
    for (final channel in channels) {
      grouped.putIfAbsent(_categoryFor(channel), () => <Channel>[]).add(channel);
    }
    _channelsByCategory = grouped;
    final counts = <String, int>{
      for (final entry in grouped.entries) entry.key: entry.value.length,
    };
    final categories = CategorySortService.sorted(counts, sortOrder);
    _cachedCounts = counts;
    _cachedCategories = <String>[_all, ...categories];
  }

  // Rebuild the permitted catalogue only when its source, permission snapshot,
  // or category ordering changes. Search and focus changes must not rescan all
  // channels and permissions on every frame.
  List<Channel> _permittedChannels(
    List<Channel> allChannels,
    FamilySessionProvider family,
    String sourceKey,
  ) {
    final permissions = family.snapshot;
    final ready = family.isReady;
    if (identical(allChannels, _indexedSourceChannels) &&
        identical(permissions, _indexedPermissions) &&
        sourceKey == _indexedSourceKey &&
        sortOrder == _indexedSortOrder && ready == _indexedReady) {
      return _visibleChannels;
    }
    final indexingTimer = Stopwatch()..start();
    _indexedSourceChannels = allChannels;
    _indexedPermissions = permissions;
    _indexedSourceKey = sourceKey;
    _indexedSortOrder = sortOrder;
    _indexedReady = ready;
    if (!ready) {
      _visibleChannels = const [];
    } else {
      // A family rule applies to a folder, not to an individual channel.
      // Resolve each category permission once, even for very large playlists.
      final allowedByCategory = <String, bool>{};
      final permitted = <Channel>[];
      for (final channel in allChannels) {
        final key = channel.categoryKey ?? '';
        final allowed = allowedByCategory.putIfAbsent(
          key,
          () => family.canAccessCategory(
            sourceKey: sourceKey,
            contentType: 'live',
            categoryKey: key,
          ),
        );
        if (allowed) permitted.add(channel);
      }
      _visibleChannels = List<Channel>.unmodifiable(permitted);
    }
    _updateCategories(_visibleChannels);
    indexingTimer.stop();
    if (kDebugMode && indexingTimer.elapsedMilliseconds >= 100) {
      debugPrint('[Streamia/LiveTV] catalogue indexing took '
          '${indexingTimer.elapsedMilliseconds}ms; '
          'total=${allChannels.length}, visible=${_visibleChannels.length}, '
          'categories=${_cachedCounts.length}');
    }
    return _visibleChannels;
  }

  String _label(String category) {
    if (category == _all) return _text('Alle Sender', 'Tüm kanallar', 'All channels');
    if (category == _other) return _text('Ohne Kategorie', 'Kategorisiz', 'Uncategorized');
    return category;
  }

  void _selectCategory(String category) {
    if (_selectedCategory != category) {
      setState(() => _selectedCategory = category);
    }
  }

  Widget _categoryPanel(List<Channel> channels, {required bool inDrawer}) {
    final colors = Theme.of(context);
    return ColoredBox(
      color: colors.brightness == Brightness.dark
          ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: sortHeader(_text('Kategorien', 'Kategoriler', 'Categories'),
              colors.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              itemCount: _cachedCategories.length,
              itemBuilder: (context, index) {
                final category = _cachedCategories[index];
                final selected = _selectedCategory == category;
                final count = category == _all
                    ? channels.length : (_cachedCounts[category] ?? 0);
                return _TvVisibleFocus(
                  key: ValueKey(category),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected
                        ? AppTheme.electricBlue.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      focusColor: AppTheme.electricBlue.withValues(alpha: 0.25),
                      autofocus: DeviceLayout.isTelevision && index == 0,
                      onTap: () {
                        _selectCategory(category);
                        if (inDrawer) Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                          child: Row(
                            children: [
                              Icon(category == _all
                                  ? Icons.live_tv_rounded : Icons.folder_outlined,
                                  size: 18,
                                  color: selected ? AppTheme.electricBlue : null),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Tooltip(
                                  message: _label(category),
                                  child: Text(
                                    _label(category),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: DeviceLayout.isTelevision ? 16 : 13,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('$count',
                                style: colors.textTheme.labelSmall?.copyWith(
                                  
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilySessionProvider>();
    final content = context.watch<ContentProvider>();
    final allChannels = content.channels;
    final channels = _permittedChannels(allChannels, family, content.sourceKey);
    final category = _cachedCategories.contains(_selectedCategory)
        ? _selectedCategory : _all;
    final filtered = _channelsForView(channels, category);

    return LayoutBuilder(builder: (context, constraints) {
      final tv = DeviceLayout.isTelevision;
      final compact = constraints.maxWidth < (tv ? 560 : 700);
      final language = context.watch<LocaleProvider>().locale.languageCode;
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            tooltip: _text('Zurück', 'Geri', 'Back'),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_text('Live-TV', 'Canlı TV', 'Live TV')),
          actions: [const ProfileClock(), if (compact)
            Builder(builder: (buttonContext) => IconButton(
              tooltip: _text('Kategorien', 'Kategoriler', 'Categories'),
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: () => Scaffold.of(buttonContext).openEndDrawer(),
            )),
          ],
        ),
        endDrawer: compact ? Drawer(
          child: SafeArea(child: _categoryPanel(channels, inDrawer: true)),
        ) : null,
        body: !family.isReady
          ? Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context).t('family_permissions_load_failed')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: family.isRefreshingPermissions
                      ? null : () => family.refreshPermissions(),
                  child: Text(AppLocalizations.of(context).t('family_retry')),
                ),
              ],
            ))
          : Row(children: [
          if (!compact)
            AnimatedContainer(
              duration: tv ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: tv ? (constraints.maxWidth * 0.26).clamp(180.0, 360.0).toDouble() : _folderFocusExpanded
                  ? (constraints.maxWidth * 0.46).clamp(285.0, 480.0)
                  : (constraints.maxWidth >= 1100 ? 340.0 : 285.0),
              child: Focus(
                onFocusChange: (focused) {
                  if (!tv && mounted && focused != _folderFocusExpanded) {
                    setState(() => _folderFocusExpanded = focused);
                  }
                },
                child: _categoryPanel(channels, inDrawer: false),
              ),
            ),
          Expanded(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(children: [
                if (compact) ...[
                  Builder(builder: (buttonContext) => IconButton(
                    tooltip: _label(category),
                    icon: const Icon(Icons.folder_open_outlined),
                    onPressed: () => Scaffold.of(buttonContext).openEndDrawer(),
                  )),
                  const SizedBox(width: 4),
                ],
                Expanded(child: SizedBox(
                  height: 48,
                  child: VoiceInputField(
                    controller: _searchController,
                    appLanguageCode: language,
                    focusNode: _searchFocus,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintText: _text('Sender suchen', 'Kanal ara', 'Search channels'),
                      hintMaxLines: 1,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _search.isEmpty ? null : IconButton(
                        tooltip: _text('Löschen', 'Temizle', 'Clear'),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _searchController.clear,
                      ),
                    ),
                  ),
                )),
                favoritesButton(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_label(favoritesOnly ? _all : category)} · ${filtered.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            Expanded(child: filtered.isEmpty
              ? Center(child: Text(
                  channels.isEmpty
                      ? _text('Keine Sender vorhanden', 'Kanal bulunamadı', 'No channels available')
                      : _text('Keine passenden Sender', 'Eşleşen kanal yok', 'No matching channels'),
                  textAlign: TextAlign.center,
                ))
              : LayoutBuilder(builder: (context, area) {
                  final width = area.maxWidth;
                  final columns = tv ? (width / 180).floor().clamp(2, 6).toInt() : width >= 1000 ? 6 : width >= 760 ? 5
                      : width >= 520 ? 4 : width >= 330 ? 3 : 2;
                  return FocusTraversalGroup(
                    child: GridView.builder(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: tv ? 164 : (width < 520 ? 118 : 136),
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _ChannelTile(
                        key: ValueKey((filtered[index].id, index)),
                        channel: filtered[index],
                      ),
                    ),
                  );
                })),
          ])),
        ]),
      );
    });
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  const _ChannelTile({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = channel.logoUrl?.trim();
    return _TvVisibleFocus(child: InkWell(
      borderRadius: BorderRadius.circular(12),
      focusColor: AppTheme.electricBlue.withValues(alpha: 0.22),
      onTap: () {
        final family = context.read<FamilySessionProvider>();
        final content = context.read<ContentProvider>();
        if (!family.isReady || !family.canAccessCategory(
          sourceKey: content.sourceKey,
          contentType: 'live',
          categoryKey: channel.categoryKey ?? '',
        )) return;
        pushWithFocusRestore(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel, isLive: true)),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.electricBlue.withValues(alpha: 0.22)),
        ),
        child: Stack(children: [
          Column(children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              child: Center(child: logo != null && logo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.contain,
                    memCacheWidth: 240,
                    memCacheHeight: 150,
                    errorWidget: (_, __, ___) => const Icon(Icons.tv_rounded, size: 30),
                  )
                : const Icon(Icons.tv_rounded, size: 30)),
            )),
            SizedBox(height: DeviceLayout.isTelevision ? 62 : 39, child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 1, 7, 5),
              child: Center(child: Text(
                channel.name,
                textAlign: TextAlign.center,
                maxLines: DeviceLayout.isTelevision ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: DeviceLayout.isTelevision ? 15 : 12, height: 1.15, fontWeight: FontWeight.w600),
              )),
            )),
          ]),
          Positioned(top: 0, right: 0, child: FavoriteToggleButton(
            contentId: channel.id,
            contentType: 'live',
            title: channel.name,
          )),
        ]),
      ),
    ));
  }
}

/// Highlights focused TV catalogue items without creating another focus stop.
class _TvVisibleFocus extends StatefulWidget {
  const _TvVisibleFocus({super.key, required this.child});
  final Widget child;
  @override
  State<_TvVisibleFocus> createState() => _TvVisibleFocusState();
}

class _TvVisibleFocusState extends State<_TvVisibleFocus> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    if (!DeviceLayout.isTelevision) return widget.child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _focused = focused);
        if (focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_focused || ModalRoute.of(context)?.isCurrent != true) return;
            if (Scrollable.maybeOf(context) != null) {
              Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 120));
            }
          });
        }
      },
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _focused ? AppTheme.electricBlue : Colors.transparent, width: 3),
        ),
        child: widget.child,
      ),
    );
  }
}

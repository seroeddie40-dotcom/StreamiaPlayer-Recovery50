import 'dart:async';
import '../widgets/profile_clock.dart';
import '../services/epg_repository.dart';
import '../services/tv_media3_controller.dart';
import '../services/playlist_source_store.dart';
import '../services/epg_source_resolver.dart';
import '../models/epg_programme.dart';
import '../widgets/tv_epg_timeline.dart';
import '../widgets/category_sort_control.dart';
import '../widgets/favorites_quick_filter.dart';
import '../services/category_sort_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/profile_favorite_outbox.dart';

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
  final ScrollController _tvChannelScroll = ScrollController();
  bool _tvMovingFocus = false;
  Timer? _previewDebounce;
  Channel? _previewChannel;
  bool _previewSuspended = false;
  bool _tvOpeningFullscreen = false;
  bool _previewPlaying = false;
  String? _previewError;
  int _previewSequence = 0;

  void _schedulePreview(Channel channel, String sourceKey) {
    _previewDebounce?.cancel();
    final sequence = ++_previewSequence;
    if (_previewChannel != null) {
      setState(() {
        _previewChannel = null;
        _previewPlaying = false;
        _previewError = null;
      });
    }
    if (_previewSuspended || !DeviceLayout.isTelevision) return;
    _previewDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || sequence != _previewSequence || _previewSuspended ||
          ModalRoute.of(context)?.isCurrent != true ||
          !identical(_tvSelectedChannel, channel)) return;
      final family = context.read<FamilySessionProvider>();
      final source = context.read<ContentProvider>();
      if (!family.isReady || source.sourceKey != sourceKey ||
          !source.channels.contains(channel) ||
          !family.canAccessCategory(
            sourceKey: source.sourceKey,
            contentType: 'live',
            categoryKey: channel.categoryKey ?? '',
          )) return;
      setState(() {
        _previewChannel = channel;
        _previewPlaying = false;
        _previewError = null;
      });
    });
  }

  void _suspendPreview() {
    _previewDebounce?.cancel();
    ++_previewSequence;
    setState(() {
      _previewSuspended = true;
      _previewChannel = null;
      _previewPlaying = false;
    });
  }

  String _selectedCategory = _all;
  bool _folderFocusExpanded = false;
  Channel? _tvSelectedChannel;
  final EpgRepository _tvEpgRepository = EpgRepository.shared;
  Future<List<EpgProgramme>>? _tvEpgFuture;
  // Reading the encrypted Xtream source for every D-pad focus change can
  // queue many secure-storage operations. Share one lookup per active source.
  String? _tvEpgSourceKey;
  Future<String?>? _tvEpgUrlFuture;

  Future<String?> _tvEpgUrlFor(String sourceKey) {
    if (_tvEpgSourceKey != sourceKey || _tvEpgUrlFuture == null) {
      _tvEpgSourceKey = sourceKey;
      // A transient secure-storage failure must not poison this shared future
      // for the entire TV session. Keep the current request safe and permit a
      // later channel selection to retry without exposing provider credentials.
      late final Future<String?> lookup;
      lookup = () async {
        try {
          final source = await PlaylistSourceStore().read(sourceKey);
          return EpgSourceResolver.resolve(source);
        } catch (_) {
          if (_tvEpgSourceKey == sourceKey &&
              identical(_tvEpgUrlFuture, lookup)) {
            _tvEpgUrlFuture = null;
          }
          return null;
        }
      }();
      _tvEpgUrlFuture = lookup;
    }
    return _tvEpgUrlFuture!;
  }
  String? _tvEpgKey;
  String _search = '';
  bool _tvFavoriteBusy = false;
  // Keep a stable focus target for each catalogue entry, including duplicate IDs.
  final Map<Channel, FocusNode> _tvChannelFocusNodes = {};
  Channel? _tvReturnChannel;

  FocusNode _focusFor(Channel channel) => _tvChannelFocusNodes.putIfAbsent(
      channel, () => FocusNode(debugLabel: 'tv-channel-${channel.id}'));

  void _restoreTvChannelFocus(Channel channel, String sourceKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final family = context.read<FamilySessionProvider>();
      final content = context.read<ContentProvider>();
      if (!family.isReady || content.sourceKey != sourceKey) return;
      final allowed = _permittedChannels(content.channels, family, sourceKey);
      final category = _cachedCategories.contains(_selectedCategory)
          ? _selectedCategory : _all;
      final filtered = _channelsForView(allowed, category);
      // Do not restore focus to a blocked, removed, or filtered-out channel.
      final target = filtered.contains(channel) ? channel
          : (filtered.isEmpty ? null : filtered.first);
      if (target == null) return;
      final node = _tvChannelFocusNodes[target];
      if (node == null || !node.canRequestFocus || node.context == null) return;
      node.requestFocus();
      final targetContext = node.context;
      if (targetContext != null && targetContext.mounted &&
          Scrollable.maybeOf(targetContext) != null) {
        Scrollable.ensureVisible(targetContext,
            duration: const Duration(milliseconds: 150),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      }
    });
  }

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
    _previewDebounce?.cancel();
    _tvEpgRepository.dispose();
    _searchFocus.dispose();
    _tvChannelScroll.dispose();
    for (final node in _tvChannelFocusNodes.values) { node.dispose(); }
    _tvChannelFocusNodes.clear();
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
      setState(() {
        _selectedCategory = category;
        // The old EPG must not remain associated with a different folder.
        _tvSelectedChannel = null;
        _tvEpgKey = null;
        _tvEpgFuture = null;
        _tvReturnChannel = null;
      });
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

  void _tvSelectChannel(Channel channel, String sourceKey) {
    if (!mounted) return;
    final key = '$sourceKey::${(channel.epgChannelId?.trim().isNotEmpty ?? false) ? channel.epgChannelId!.trim() : channel.id}';
    if (_tvSelectedChannel == channel && _tvEpgKey == key) return;
    _schedulePreview(channel, sourceKey);
    setState(() {
      _tvSelectedChannel = channel;
      if (_tvEpgKey != key) {
        _tvEpgKey = key;
        _tvEpgFuture = () async {
          final url = await _tvEpgUrlFor(sourceKey);
          if (url == null || url.trim().isEmpty) return <EpgProgramme>[];
          return _tvEpgRepository.programmes(url, (channel.epgChannelId?.trim().isNotEmpty ?? false) ? channel.epgChannelId!.trim() : channel.id);
        }();
      }
    });
  }

  // TV remote long-OK: toggle the focused channel directly, without a
  // second focus stop or an expensive favorite widget for every list row.
  Future<void> _toggleTvFavorite(Channel channel, String sourceKey) async {
    if (_tvFavoriteBusy || !SupabaseConfig.isConfigured) return;
    final family = context.read<FamilySessionProvider>();
    final profile = family.activeProfile;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (!family.isReady || profile == null || user == null ||
        !family.canAccessCategory(sourceKey: sourceKey,
          contentType: 'live', categoryKey: channel.categoryKey ?? '')) return;
    final profileId = profile.id;
    final token = family.parentAccessToken;
    bool stillCurrent() => mounted && family.isReady &&
        family.activeProfile?.id == profileId &&
        family.parentAccessToken == token &&
        client.auth.currentUser?.id == user.id &&
        context.read<ContentProvider>().sourceKey == sourceKey &&
        family.canAccessCategory(sourceKey: sourceKey,
          contentType: 'live', categoryKey: channel.categoryKey ?? '');
    _tvFavoriteBusy = true;
    try {
      final rows = await ProfileFavoriteOutbox.load(
        client, user.id, profileId, token, stillCurrent);
      if (!stillCurrent()) return;
      final current = rows.any((row) => row['source_key'] == sourceKey &&
          row['content_type'] == 'live' &&
          row['content_id'].toString() == channel.id);
      await ProfileFavoriteOutbox.enqueue(user.id, profileId, sourceKey,
          'live', channel.id, channel.name,
          context.read<ContentProvider>().sourceLabel ?? '', !current);
      if (!stillCurrent()) return;
      favoritesRevision.value++;
      await ProfileFavoriteOutbox.flush(client, user.id, profileId,
          token, stillCurrent);
      if (stillCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(current
              ? _text('Aus Favoriten entfernt', 'Favorilerden kaldırıldı', 'Removed from favorites')
              : _text('Zu Favoriten hinzugefügt', 'Favorilere eklendi', 'Added to favorites')),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_text('Favorit konnte nicht gespeichert werden',
            'Favori kaydedilemedi', 'Could not save favorite')),
      ));
    } finally {
      _tvFavoriteBusy = false;
    }
  }

  // Move focus by catalogue index rather than relying on geometric focus
  // traversal. Off-screen ListView.builder rows do not yet have a BuildContext.
  Future<void> _moveTvChannelFocus(List<Channel> channels, int index) async {
    if (_tvMovingFocus || index < 0 || index >= channels.length) return;
    _tvMovingFocus = true;
    try {
      final target = channels[index];
      if (_tvChannelScroll.hasClients) {
        // Every TV row has a fixed extent, so an off-screen destination can
        // be materialized without scanning or laying out the entire playlist.
        final position = _tvChannelScroll.position;
        final desired = (index * 66.0 - position.viewportDimension / 2 + 33)
            .clamp(0.0, position.maxScrollExtent);
        await _tvChannelScroll.animateTo(desired,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut);
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final node = _tvChannelFocusNodes[target];
      if (node != null && node.context != null && node.canRequestFocus) {
        node.requestFocus();
      }
    } finally {
      _tvMovingFocus = false;
    }
  }

  Widget _tvChannelList(List<Channel> filtered, String sourceKey) {
    return ListView.builder(
      key: const PageStorageKey('streamia_tv_channel_list'),
      controller: _tvChannelScroll,
      itemExtent: 66,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final channel = filtered[index];
        final selected = identical(channel, _tvSelectedChannel);
        final focusNode = _focusFor(channel);
        focusNode.onKeyEvent = (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowDown) {
            _moveTvChannelFocus(filtered, index + 1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            if (index == 0) return KeyEventResult.ignored;
            _moveTvChannelFocus(filtered, index - 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: _TvVisibleFocus(child: InkWell(
            focusNode: focusNode,
            autofocus: index == 0,
            focusColor: AppTheme.electricBlue.withValues(alpha: 0.28),
            onFocusChange: (focused) {
              if (!focused) return;
              _tvSelectChannel(channel, sourceKey);
              // A lazily built row can receive D-pad focus while partly outside
              // the viewport. Bring that actual focused row into view, rather
              // than leaving the selection painted on the first visible row.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final node = _tvChannelFocusNodes[channel];
                if (node == null || !node.hasFocus) return;
                final rowContext = node.context;
                if (rowContext == null || !rowContext.mounted) return;
                Scrollable.ensureVisible(
                  rowContext,
                  duration: const Duration(milliseconds: 110),
                  alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                );
              });
            },
            onLongPress: () => _toggleTvFavorite(channel, sourceKey),
            onTap: () async {
              // OK can be delivered more than once while a PlatformView is
              // being removed. Never open overlapping fullscreen routes.
              if (_tvOpeningFullscreen) return;
              final family = context.read<FamilySessionProvider>();
              if (!family.isReady || !family.canAccessCategory(
                sourceKey: sourceKey,
                contentType: 'live',
                categoryKey: channel.categoryKey ?? '',
              )) return;
              _tvOpeningFullscreen = true;
              _tvSelectChannel(channel, sourceKey);
              _tvReturnChannel = channel;
              _suspendPreview();
              try {
                // Remove the catalogue PlatformView before constructing the
                // fullscreen player. Native Media3 ownership is also exclusive.
                await WidgetsBinding.instance.endOfFrame;
                if (!mounted) return;
                // Permission and playlist state may have changed during the
                // asynchronous route handoff. Never use a stale authorization.
                final currentFamily = context.read<FamilySessionProvider>();
                final currentContent = context.read<ContentProvider>();
                if (!currentFamily.isReady ||
                    currentContent.sourceKey != sourceKey ||
                    !currentContent.channels.contains(channel) ||
                    !currentFamily.canAccessCategory(
                      sourceKey: sourceKey,
                      contentType: 'live',
                      categoryKey: channel.categoryKey ?? '',
                    )) return;
                await pushWithFocusRestore(context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel, isLive: true)));
              } finally {
                if (mounted) {
                  _tvOpeningFullscreen = false;
                  _tvReturnChannel = null;
                  setState(() => _previewSuspended = false);
                  _schedulePreview(channel, sourceKey);
                  _restoreTvChannelFocus(channel, sourceKey);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.electricBlue.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(children: [
                const Icon(Icons.tv_rounded, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (selected) const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          )),
        );
      },
    );
  }

  Widget _tvPreview(List<Channel> filtered) {
    final channel = filtered.contains(_tvSelectedChannel)
        ? _tvSelectedChannel : (filtered.isEmpty ? null : filtered.first);
    if (channel == null) return const Center(child: Text('Keine Sender verfügbar'));
    final logo = channel.logoUrl?.trim();
    final sourceKey = context.read<ContentProvider>().sourceKey;
    final key = '$sourceKey::${(channel.epgChannelId?.trim().isNotEmpty ?? false) ? channel.epgChannelId!.trim() : channel.id}';
    final preview = _previewChannel;
    final previewSequence = _previewSequence;
    final previewAllowed = preview != null &&
        filtered.contains(preview) &&
        context.read<FamilySessionProvider>().isReady &&
        context.read<FamilySessionProvider>().canAccessCategory(
          sourceKey: sourceKey,
          contentType: 'live',
          categoryKey: preview.categoryKey ?? '',
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 160, child: Stack(fit: StackFit.expand, children: [
        // Keep one native PlatformView for the entire catalogue lifetime.
        // An empty URL stops playback while the preview is suspended or
        // forbidden; changing channels reuses the same decoder owner.
        if (!_previewSuspended) TvMedia3View(
            key: const ValueKey('streamia-tv-catalogue-preview'),
            url: previewAllowed && !_previewSuspended ? preview.streamUrl : '', 
            onState: (state, playing) {
              if (mounted && !_previewSuspended && preview != null &&
                  previewSequence == _previewSequence &&
                  identical(_previewChannel, preview) &&
                  _previewPlaying != playing) {
                setState(() => _previewPlaying = playing);
              }
            },
            onError: (code) {
              if (mounted && !_previewSuspended && preview != null &&
                  previewSequence == _previewSequence &&
                  identical(_previewChannel, preview)) {
                setState(() => _previewError = code);
              }
            },
          ),
        if (!previewAllowed || !_previewPlaying || _previewError != null)
          Center(child: previewAllowed && _previewError != null
              ? const Icon(Icons.error_outline_rounded, size: 40)
              : logo != null && logo.isNotEmpty
                  ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain,
                      memCacheWidth: 320, memCacheHeight: 200,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.live_tv_rounded, size: 48))
                  : const Icon(Icons.live_tv_rounded, size: 48)),
      ])),
      Padding(padding: const EdgeInsets.all(12), child: Text(channel.name,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium)),
      const Divider(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(_text('Programmübersicht', 'Program rehberi', 'TV guide'))),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(8),
        child: _tvEpgKey != key || _tvEpgFuture == null
          ? Text(_text('Sender wählen, um EPG zu laden', 'EPG için kanal seçin', 'Select a channel for EPG'))
          : FutureBuilder<List<EpgProgramme>>(
              future: _tvEpgFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(_text('EPG nicht verfügbar', 'EPG kullanılamıyor', 'EPG unavailable'));
                if (!snapshot.hasData) return const LinearProgressIndicator();
                // Catalogue EPG is a passive preview. Only the fullscreen
                // player's timeline should own D-pad focus/navigation.
                return ExcludeFocus(
                  child: TvEpgTimeline(key: ValueKey(key), programmes: snapshot.data!),
                );
              },
            ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilySessionProvider>();
    final content = context.watch<ContentProvider>();
    // Do not retain a credential-bearing EPG URL across playlist switches.
    if (_tvEpgSourceKey != null && _tvEpgSourceKey != content.sourceKey) {
      _tvEpgSourceKey = null;
      _tvEpgUrlFuture = null;
      _tvEpgKey = null;
      _tvEpgFuture = null;
    }
    final allChannels = content.channels;
    final channels = _permittedChannels(allChannels, family, content.sourceKey);
    final category = _cachedCategories.contains(_selectedCategory)
        ? _selectedCategory : _all;
    final filtered = _channelsForView(channels, category);
    // A previously focused channel may disappear after a family permission,
    // source, category or favorites-filter change. Never preview it again.
    if (_tvSelectedChannel != null && !filtered.contains(_tvSelectedChannel)) {
      _previewDebounce?.cancel();
      ++_previewSequence;
      _previewChannel = null;
      _previewPlaying = false;
      _tvSelectedChannel = null;
      _tvEpgKey = null;
      _tvEpgFuture = null;
      _tvReturnChannel = null;
    }

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
                child: FocusTraversalGroup(child: _categoryPanel(channels, inDrawer: false)),
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
            if (tv && !compact)
              Expanded(child: Row(children: [
                Expanded(flex: 5, child: FocusTraversalGroup(child: _tvChannelList(filtered, content.sourceKey))),
                const VerticalDivider(width: 1),
                Expanded(flex: 6, child: FocusTraversalGroup(child: _tvPreview(filtered))),
              ]))
            else Expanded(child: filtered.isEmpty
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

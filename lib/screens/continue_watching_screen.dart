import '../widgets/tv_catalog_focus.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/platform/device_layout.dart';
import '../core/localization/app_localizations.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import '../services/watch_progress_service.dart';
import 'player_screen.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});

  @override
  State<ContinueWatchingScreen> createState() =>
      _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState
    extends State<ContinueWatchingScreen> {
  late final WatchProgressService _service;

  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _service = WatchProgressService(family: context.read<FamilySessionProvider>());
    _load();
  }

  void _load() {
    _items = _service.loadRecent(
      sourceKey:
          context.read<ContentProvider>().sourceKey,
    );
  }

  Future<void> _refresh() async {
    final next = _service.loadRecent(
      sourceKey:
          context.read<ContentProvider>().sourceKey,
    );

    setState(() => _items = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusColor = Theme.of(context)
        .colorScheme
        .primary
        .withValues(alpha: 0.16);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('continue_title')),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            focusColor: focusColor,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                autofocus: DeviceLayout.isTelevision,
                style: TextButton.styleFrom(
                  overlayColor: focusColor,
                ),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(
                  l10n.t('continue_unavailable'),
                ),
              ),
            );
          }

          final content = context.watch<ContentProvider>();
          final family = context.watch<FamilySessionProvider>();
          final rows =
              (_service.isCurrent ? (snapshot.data ?? const <Map<String, dynamic>>[]) : const <Map<String, dynamic>>[])
                  .where((row) => _isAllowed(row, content, family))
                  .toList(growable: false);

          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height:
                        MediaQuery.sizeOf(context).height *
                            0.35,
                  ),
                  Center(
                    child: Text(
                      l10n.t('continue_empty'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: FocusTraversalGroup(
              child: ListView.separated(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];

                  final title =
                      row['title']?.toString() ??
                          'Unbekannter Titel';

                  final pos =
                      (row['position_seconds'] as num?)
                              ?.toInt() ??
                          0;

                  final duration =
                      (row['duration_seconds'] as num?)
                              ?.toInt() ??
                          0;

                  final progress = duration > 0
                      ? (pos / duration)
                          .clamp(0.0, 1.0)
                          .toDouble()
                      : 0.0;

                  return TvCatalogFocus(child: ListTile(
                    autofocus:
                        DeviceLayout.isTelevision && index == 0,
                    focusColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.14),
                    leading: const Icon(
                      Icons.play_circle_outline,
                      size: 36,
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_time(pos)}'
                          '${duration > 0 ? ' / ${_time(duration)}' : ''}',
                        ),
                      ],
                    ),
                    onTap: () async {
                      await _resume(row);

                      if (mounted) {
                        await _refresh();
                      }
                    },
                  ));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isAllowed(
    Map<String, dynamic> row,
    ContentProvider content,
    FamilySessionProvider family,
  ) {
    if (!family.isReady) return false;

    final type = row['content_type']?.toString() ?? '';
    final id = row['content_id']?.toString() ?? '';
    if (id.isEmpty || content.sourceKey.isEmpty) return false;

    if (type == 'vod') {
      for (final item in content.vodItems) {
        if (item.id == id) {
          return family.canAccessCategory(
            sourceKey: content.sourceKey,
            contentType: 'vod',
            categoryKey: item.categoryKey ?? '',
          );
        }
      }
      return false;
    }

    if (type == 'series') {
      final parts = id.split('::');
      if (parts.length < 2) return false;

      final seriesId = parts.first;
      final episodeId = parts.sublist(1).join('::');

      for (final item in content.series) {
        if (item.id != seriesId) continue;

        final hasEpisode = item.seasons.any(
          (season) => season.episodes.any(
            (episode) => episode.id == episodeId,
          ),
        );

        return hasEpisode &&
            family.canAccessCategory(
              sourceKey: content.sourceKey,
              contentType: 'series',
              categoryKey: item.categoryKey ?? '',
            );
      }
      return false;
    }

    return false;
  }

  Future<void> _resume(
    Map<String, dynamic> row,
  ) async {
    final content = context.read<ContentProvider>();
    final family = context.read<FamilySessionProvider>();

    if (!_isAllowed(row, content, family)) {
      _missingSource();
      return;
    }

    final type = row['content_type']?.toString();
    final id = row['content_id']?.toString() ?? '';

    if (type == 'vod') {
      final matches =
          content.vodItems.where((v) => v.id == id);

      final item =
          matches.isEmpty ? null : matches.first;

      if (item == null) {
        _missingSource();
        return;
      }

      await pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: item.streamUrl,
            title: item.title,
            contentId: item.id,
          ),
        ),
      );

      return;
    }

    if (type == 'series') {
      final parts = id.split('::');
      final seriesId = parts.first;

      final episodeId = parts.length > 1
          ? parts.sublist(1).join('::')
          : '';

      final matches = content.series.where(
        (s) => s.id == seriesId,
      );

      final series =
          matches.isEmpty ? null : matches.first;

      if (series == null) {
        _missingSource();
        return;
      }

      final episodes = series.seasons
          .expand((season) => season.episodes)
          .toList();

      final index = episodes.indexWhere(
        (e) => e.id == episodeId,
      );

      if (index < 0) {
        _missingSource();
        return;
      }

      await pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            episodes: episodes,
            initialEpisodeIndex: index,
            title: series.title,
            series: series,
            contentId: series.id,
          ),
        ),
      );

      return;
    }

    _missingSource();
  }

  void _missingSource() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)
              .t('continue_unavailable'),
        ),
      ),
    );
  }

  String _time(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds ~/ 60) % 60;
    final s = seconds % 60;

    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:'
            '${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import '../core/focus_navigation.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../providers/content_provider.dart';
import '../services/watch_progress_service.dart';
import 'player_screen.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});
  @override
  State<ContinueWatchingScreen> createState() => _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState extends State<ContinueWatchingScreen> {
  final WatchProgressService _service = WatchProgressService();
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = _service.loadRecent(
      sourceKey: context.read<ContentProvider>().sourceKey,
    );
  }

  Future<void> _refresh() async {
    final next = _service.loadRecent(
      sourceKey: context.read<ContentProvider>().sourceKey,
    );
    setState(() => _items = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('continue_title')),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                autofocus: true,
                style: TextButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16)),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.t('continue_unavailable')),
              ),
            );
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
                  Center(child: Text(l10n.t('continue_empty'))),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: FocusTraversalGroup(
              child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                final title = row['title']?.toString() ?? 'Unbekannter Titel';
                final pos = (row['position_seconds'] as num?)?.toInt() ?? 0;
                final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
                final progress = duration > 0
                    ? (pos / duration).clamp(0.0, 1.0).toDouble()
                    : 0.0;
                return ListTile(
                  autofocus: index == 0,
                  focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                  leading: const Icon(Icons.play_circle_outline, size: 36),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text('${_time(pos)}${duration > 0 ? ' / ${_time(duration)}' : ''}'),
                    ],
                  ),
                  onTap: () async {
                    await _resume(row);
                    if (mounted) await _refresh();
                  },
                );
              },
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resume(Map<String, dynamic> row) async {
    final content = context.read<ContentProvider>();
    final type = row['content_type']?.toString();
    final id = row['content_id']?.toString() ?? '';
    if (type == 'vod') {
      final matches = content.vodItems.where((v) => v.id == id);
      final item = matches.isEmpty ? null : matches.first;
      if (item == null) return _missingSource();
      await pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        streamUrl: item.streamUrl, title: item.title, contentId: item.id,
      )));
      return;
    }
    if (type == 'series') {
      final parts = id.split('::');
      final seriesId = parts.first;
      final episodeId = parts.length > 1 ? parts.sublist(1).join('::') : '';
      final matches = content.series.where((s) => s.id == seriesId);
      final series = matches.isEmpty ? null : matches.first;
      if (series == null) return _missingSource();
      final episodes = series.seasons.expand((season) => season.episodes).toList();
      final index = episodes.indexWhere((e) => e.id == episodeId);
      if (index < 0) return _missingSource();
      await pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        episodes: episodes,
        initialEpisodeIndex: index,
        title: series.title,
        series: series,
        contentId: series.id,
      )));
      return;
    }
    _missingSource();
  }

  void _missingSource() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).t('continue_unavailable')),
    ));
  }

  String _time(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds ~/ 60) % 60;
    final s = seconds % 60;
    return h > 0
        ? '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m}:${s.toString().padLeft(2, '0')}';
  }
}

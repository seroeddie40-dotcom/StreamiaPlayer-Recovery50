import 'package:flutter/material.dart';
import '../core/focus_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/favorites_backup_service.dart';
import '../providers/content_provider.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import 'player_screen.dart';
import 'vod_screen.dart';
import 'series_screen.dart';

/// Displays account-synchronized favorites. Stream URLs and credentials are
/// intentionally not stored in the favorites table, so playback is launched
/// from the currently loaded playlist rather than from this metadata-only list.
class FavoritesLibraryScreen extends StatefulWidget {
  const FavoritesLibraryScreen({super.key});

  @override
  State<FavoritesLibraryScreen> createState() => _FavoritesLibraryScreenState();
}

class _FavoritesLibraryScreenState extends State<FavoritesLibraryScreen> {
  late final FavoritesBackupService _service;
  late Future<List<Map<String, dynamic>>> _favorites;
  int _selectedType = 0;
  static const _types = ['live', 'vod', 'series'];
  static const _labels = ['Sender', 'Filme', 'Serien'];
  static const _icons = [Icons.live_tv, Icons.movie, Icons.video_library];

  @override
  void initState() {
    super.initState();
    _service = FavoritesBackupService(Supabase.instance.client);
    _favorites = _service.loadAll();
  }

  void _reload() => setState(() => _favorites = _service.loadAll());

  Future<void> _openFavorite(Map<String, dynamic> row) async {
    final content = context.read<ContentProvider>();
    final sourceKey = row['source_key']?.toString();
    if (sourceKey == null || sourceKey != content.sourceKey) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte zuerst die ursprüngliche Playlist bzw. Quelle laden. Favoriten enthalten bewusst keine Stream-URLs.'),
      ));
      return;
    }
    final id = row['content_id']?.toString();
    final type = row['content_type']?.toString();
    if (id == null) return;
    if (type == 'live') {
      Channel? item;
      for (final candidate in content.channels) { if (candidate.id == id) { item = candidate; break; } }
      if (item != null && mounted) {
        await pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: item, isLive: true)));
        return;
      }
    } else if (type == 'vod') {
      VodItem? item;
      for (final candidate in content.vodItems) { if (candidate.id == id) { item = candidate; break; } }
      if (item != null && mounted) {
        await pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => VodDetailScreen(item: item!)));
        return;
      }
    } else if (type == 'series') {
      Series? item;
      for (final candidate in content.series) { if (candidate.id == id) { item = candidate; break; } }
      if (item != null && mounted) {
        await pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: item!)));
        return;
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Dieser Eintrag ist in der aktuell geladenen Quelle nicht mehr verfügbar.'),
    ));
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorit entfernen?'),
        content: Text('„${row['title']}“ aus deinen Favoriten entfernen?'),
        actions: [
          TextButton(
            autofocus: true,
            style: TextButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.20)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.remove(
        contentId: row['content_id'].toString(),
        contentType: row['content_type'].toString(),
        sourceKey: row['source_key'].toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorit entfernt.')));
        _reload();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favorit konnte nicht entfernt werden: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meine Favoriten'),
      actions: [IconButton(tooltip: 'Aktualisieren', focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16), onPressed: _reload, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < _labels.length; i++)
                ButtonSegment(value: i, label: Text(_labels[i]), icon: Icon(_icons[i])),
            ],
            selected: {_selectedType},
            style: ButtonStyle(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16)),
            onSelectionChanged: (selection) => setState(() => _selectedType = selection.first),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _favorites,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(message: 'Favoriten konnten nicht geladen werden: ${snapshot.error}', onRetry: _reload);
              }
              final rows = (snapshot.data ?? [])
                  .where((row) => row['content_type'] == _types[_selectedType])
                  .toList();
              if (rows.isEmpty) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icons[_selectedType], size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Noch keine ${_labels[_selectedType]}-Favoriten.'),
                    const SizedBox(height: 6),
                    const Text('Füge Favoriten in der jeweiligen Medienübersicht hinzu.'),
                  ],
                ));
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: FocusTraversalGroup(
                  child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      autofocus: index == 0,
                      focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                      onTap: () => _openFavorite(row),
                      leading: Icon(_icons[_selectedType]),
                      title: Text(row['title']?.toString() ?? 'Unbenannter Favorit'),
                      subtitle: Text('${row['source_label']?.toString() ?? 'Gespeicherte Playlist-Quelle'} · Antippen zum Öffnen'),
                      trailing: IconButton(
                        tooltip: 'Aus Favoriten entfernen',
                        focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                        icon: const Icon(Icons.favorite, color: Colors.redAccent),
                        onPressed: () => _remove(row),
                      ),
                    );
                  },
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16)), onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen')),
      ]),
    ),
  );
}

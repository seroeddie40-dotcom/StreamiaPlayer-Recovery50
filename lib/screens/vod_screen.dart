import 'package:flutter/material.dart';
import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../providers/content_provider.dart';
import '../providers/locale_provider.dart';
import '../models/vod_item.dart';
import '../services/download_service.dart';
import 'player_screen.dart';
import '../widgets/favorite_toggle_button.dart';

class VodScreen extends StatelessWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ContentProvider>().vodItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Filme')),
      body: items.isEmpty
          ? const Center(child: Text('Keine Filme vorhanden'))
          : FocusTraversalGroup(child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.6,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _VodTile(item: items[i], autofocus: i == 0),
            )),
    );
  }
}

class _VodTile extends StatefulWidget {
  final VodItem item;
  final bool autofocus;
  const _VodTile({required this.item, this.autofocus = false});

  @override
  State<_VodTile> createState() => _VodTileState();
}

class _VodTileState extends State<_VodTile> {
  double _progress = 0;
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await DownloadService.download(
        url: widget.item.streamUrl,
        filename: '${widget.item.title.replaceAll(RegExp(r"[^A-Za-z0-9]"), "_")}.mp4',
        onProgress: (r, t) { if (t > 0 && mounted) setState(() => _progress = r / t); },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('download_failed'))),
        );
      }
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      autofocus: widget.autofocus,
      focusColor: AppTheme.electricBlue.withOpacity(0.22),
      onTap: () async {
        final language = context.read<LocaleProvider>().locale.languageCode;
        final enriched = await context.read<ContentProvider>().enrichVodMetadata(
          widget.item.id, language: language);
        if (!context.mounted) return;
        pushWithFocusRestore(context, MaterialPageRoute(
          builder: (_) => VodDetailScreen(item: enriched ?? widget.item)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.item.posterUrl != null
                      ? CachedNetworkImage(imageUrl: widget.item.posterUrl!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.movie, size: 48))
                      : const Icon(Icons.movie, size: 48),
                  Positioned(
                    left: 4, top: 4,
                    child: FavoriteToggleButton(contentId: widget.item.id, contentType: 'vod', title: widget.item.title),
                  ),
                  Positioned(
                    right: 4, top: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: _downloading ? 'Download läuft' : 'Film herunterladen',
                        focusColor: AppTheme.electricBlue.withOpacity(0.35),
                        onPressed: _downloading ? null : _download,
                        icon: Icon(_downloading ? Icons.downloading : Icons.download,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  if (_downloading && _progress > 0)
                    Positioned(left: 0, right: 0, bottom: 0,
                      child: LinearProgressIndicator(value: _progress, backgroundColor: Colors.black45, color: AppTheme.electricBlue)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (widget.item.releaseDate != null || widget.item.genre != null)
                    Text([widget.item.releaseDate, widget.item.genre].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class VodDetailScreen extends StatelessWidget {
  final VodItem item;
  const VodDetailScreen({super.key, required this.item});

  String _durationLabel(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours} Std. ${minutes} Min.' : '$minutes Min.';
  }

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (item.releaseDate != null) item.releaseDate!,
      if (item.genre != null) item.genre!,
      if (item.durationSeconds != null) _durationLabel(item.durationSeconds!),
      if (item.ageRating != null) item.ageRating!,
      if (item.rating != null && item.rating! > 0) '★ ${item.rating!.toStringAsFixed(1)}',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(item.title), actions: [FavoriteToggleButton(contentId: item.id, contentType: 'vod', title: item.title)]),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            child: Stack(fit: StackFit.expand, children: [
              if (item.backdropUrl != null)
                CachedNetworkImage(imageUrl: item.backdropUrl!, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.08), Colors.black.withOpacity(0.88)]))),
              Align(alignment: Alignment.bottomLeft, child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(item.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(24), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (facts.isNotEmpty) Wrap(spacing: 12, runSpacing: 8,
                children: facts.map((fact) => Chip(label: Text(fact))).toList()),
              if (item.plot != null && item.plot!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Beschreibung', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8), Text(item.plot!),
              ],
              if (item.director != null) ...[
                const SizedBox(height: 12), Text('Regie: ${item.director}'),
              ],
              if (item.cast != null) ...[
                const SizedBox(height: 8), Text('Besetzung: ${item.cast}'),
              ],
              if (item.metadataAttribution != null) ...[
                const SizedBox(height: 12),
                Text(item.metadataAttribution!, style: Theme.of(context).textTheme.bodySmall),
                if (item.metadataSourceUrl != null)
                  SelectableText(item.metadataSourceUrl!, style: Theme.of(context).textTheme.bodySmall),
                if (item.metadataLicense != null)
                  Text('Lizenz: ${item.metadataLicense}', style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => pushWithFocusRestore(context, MaterialPageRoute(builder: (_) => PlayerScreen(streamUrl: item.streamUrl, title: item.title, contentId: item.id))),
                icon: const Icon(Icons.play_arrow), label: const Text('Abspielen'),
              ),
            ],
          )),
        ],
      ),
    );
  }
}

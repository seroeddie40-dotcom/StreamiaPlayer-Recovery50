import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/content_provider.dart';
import '../providers/locale_provider.dart';
import '../models/series.dart';
import '../services/download_service.dart';
import '../services/playlist_source_store.dart';
import '../services/xtream_service.dart';
import '../widgets/favorite_toggle_button.dart';
import 'player_screen.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ContentProvider>().series;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serien'),
      ),
      body: list.isEmpty
          ? const Center(
              child: Text('Keine Serien vorhanden'),
            )
          : FocusTraversalGroup(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.6,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _SeriesTile(
                  series: list[i],
                  autofocus: i == 0,
                ),
              ),
            ),
    );
  }
}

class _SeriesTile extends StatelessWidget {
  final Series series;
  final bool autofocus;

  const _SeriesTile({
    required this.series,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      autofocus: autofocus,
      focusColor:
          AppTheme.electricBlue.withValues(alpha: 0.22),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            series: series,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: series.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: series.posterUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(
                            Icons.video_library,
                            size: 48,
                          ),
                        )
                      : const Icon(
                          Icons.video_library,
                          size: 48,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (series.releaseDate != null ||
                          series.genre != null)
                        Text(
                          [
                            series.releaseDate,
                            series.genre,
                          ]
                              .whereType<String>()
                              .where((v) => v.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              left: 4,
              child: FavoriteToggleButton(
                contentId: series.id,
                contentType: 'series',
                title: series.title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({
    super.key,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState
    extends State<SeriesDetailScreen> {
  bool _loadingEpisodes = false;
  String? _episodeError;
  bool _detailsRequested = false;
  String? _openedSourceKey;

  Future<void> _loadEpisodes() async {
    if (_loadingEpisodes) return;
    final content = context.read<ContentProvider>();
    final sourceKey = content.sourceKey;
    final current = content.series.firstWhere(
      (item) => item.id == widget.series.id,
      orElse: () => widget.series,
    );
    if (current.seasons.isNotEmpty) return;
    setState(() {
      _loadingEpisodes = true;
      _episodeError = null;
    });
    XtreamService? service;
    try {
      final config = await PlaylistSourceStore().read(sourceKey);
      if (config == null || config.type != 'xtream') {
        if (mounted) setState(() => _episodeError = 'Keine Episoden in dieser Playlist vorhanden.');
        return;
      }
      if (config.serverUrl == null || config.username == null || config.password == null) {
        throw const FormatException('Xtream-Zugangsdaten sind unvollständig.');
      }
      service = XtreamService(
        baseUrl: config.serverUrl!,
        username: config.username!,
        password: config.password!,
      );
      final details = await service.getSeriesDetails(current);
      if (!mounted || content.sourceKey != sourceKey) return;
      final updated = List<Series>.of(content.series);
      final index = updated.indexWhere((item) => item.id == current.id);
      if (index < 0) return;
      // Avoid replacing data that may have arrived from another request.
      if (updated[index].seasons.isNotEmpty) return;
      updated[index] = details;
      content.replaceLibrary(
        channels: content.channels,
        vod: content.vodItems,
        series: updated,
        sourceKey: sourceKey,
        sourceLabel: content.sourceLabel,
      );
      if (details.seasons.isEmpty && mounted) {
        setState(() => _episodeError = 'Der Server hat keine Episoden für diese Serie geliefert.');
      }
    } catch (error) {
      if (mounted && content.sourceKey == sourceKey) {
        setState(() => _episodeError = error is XtreamConnectionException
            ? error.message
            : 'Episoden konnten nicht geladen werden. Bitte erneut versuchen.');
      }
    } finally {
      service?.close();
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) return;

        final language =
            context.read<LocaleProvider>()
                .locale
                .languageCode;

        final content = context.read<ContentProvider>();
        _openedSourceKey = content.sourceKey;
        // Do not delay episode loading for an optional metadata lookup.
        if (!_detailsRequested) {
          _detailsRequested = true;
          _loadEpisodes();
        }
        await content.enrichSeriesMetadata(
          widget.series.id,
          language: language,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final series =
        context.select<ContentProvider, Series>(
      (content) => content.series.firstWhere(
        (item) => item.id == widget.series.id,
        orElse: () => widget.series,
      ),
    );

    final sourceChanged = _openedSourceKey != null &&
        context.read<ContentProvider>().sourceKey != _openedSourceKey;
    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          FavoriteToggleButton(
            contentId: series.id,
            contentType: 'series',
            title: series.title,
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (series.backdropUrl != null)
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: series.backdropUrl!,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (series.posterUrl != null)
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: series.posterUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (series.plot != null)
                    Text(series.plot!),
                  if (series.genre != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Genre: ${series.genre}',
                    ),
                  ],
                  if (series.releaseDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Erscheinungsdatum: '
                      '${series.releaseDate}',
                    ),
                  ],
                  if (series.ageRating != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Altersfreigabe: '
                      '${series.ageRating}',
                    ),
                  ],
                  if (series.rating != null &&
                      series.rating! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Bewertung: ★ '
                      '${series.rating!.toStringAsFixed(1)}',
                    ),
                  ],
                  if (series.cast != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Besetzung: ${series.cast}',
                    ),
                  ],
                  if (series.metadataAttribution !=
                      null) ...[
                    const SizedBox(height: 12),
                    Text(
                      series.metadataAttribution!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    if (series.metadataSourceUrl != null)
                      SelectableText(
                        series.metadataSourceUrl!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    if (series.metadataLicense != null)
                      Text(
                        'Lizenz: '
                        '${series.metadataLicense}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                  ],
                ],
              ),
            ),
          ),
           Expanded(
             child: sourceChanged
                 ? const Center(child: Text('Die aktive Playlist wurde gewechselt. Bitte zurückgehen.'))
                 : _loadingEpisodes && series.seasons.isEmpty
                     ? const Center(child: CircularProgressIndicator())
                     : series.seasons.isEmpty
                         ? Center(
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text(_episodeError ?? 'Keine Episoden vorhanden.'),
                                 const SizedBox(height: 12),
                                 FilledButton.icon(
                                   onPressed: _loadingEpisodes ? null : _loadEpisodes,
                                   icon: const Icon(Icons.refresh),
                                   label: const Text('Erneut laden'),
                                 ),
                               ],
                             ),
                           )
                         : ListView.builder(
               itemCount: series.seasons.length,
               itemBuilder: (context, i) =>
                   _SeasonSection(
                series: series,
                season: series.seasons[i],
                autofocusFirstEpisode: i == 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonSection extends StatelessWidget {
  final Series series;
  final Season season;
  final bool autofocusFirstEpisode;

  const _SeasonSection({
    required this.series,
    required this.season,
    this.autofocusFirstEpisode = false,
  });

  Future<void> _downloadSeason(
    BuildContext context,
  ) async {
    var failed = false;

    for (final ep in season.episodes) {
      try {
        await DownloadService.download(
          url: ep.streamUrl,
          filename:
              '${series.title}_S${season.number}'
              'E${ep.number}.mp4',
        );
      } catch (_) {
        failed = true;
      }
    }

    if (failed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .t('download_season_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Staffel ${season.number}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () =>
                    _downloadSeason(context),
                icon: const Icon(
                  Icons.download,
                  size: 18,
                ),
                label: const Text(
                  'Staffel herunterladen',
                ),
              ),
            ],
          ),
        ),
        FocusTraversalGroup(
          child: Column(
            children: season.episodes
                .asMap()
                .entries
                .map((entry) {
              final ep = entry.value;

              return InkWell(
                autofocus:
                    autofocusFirstEpisode &&
                        entry.key == 0,
                focusColor: AppTheme.electricBlue
                    .withValues(alpha: 0.18),
                onTap: () => pushWithFocusRestore(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      episodes: season.episodes,
                      initialEpisodeIndex:
                          season.episodes.indexOf(ep),
                      title:
                          '${series.title} - ${ep.title}',
                      series: series,
                      contentId: series.id,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: ep.stillUrl != null
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: ep.stillUrl!,
                            width: 76,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                CircleAvatar(
                              child: Text(
                                '${ep.number}',
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          child: Text(
                            '${ep.number}',
                          ),
                        ),
                  title: Text(ep.title),
                  subtitle: ep.plot == null &&
                          ep.releaseDate == null &&
                          ep.durationSeconds == null &&
                          ep.metadataAttribution == null
                      ? null
                      : Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (ep.releaseDate != null ||
                                ep.durationSeconds !=
                                    null)
                              Text(
                                [
                                  if (ep.releaseDate !=
                                      null)
                                    ep.releaseDate!,
                                  if (ep.durationSeconds !=
                                      null)
                                    '${ep.durationSeconds! ~/ 60} Min.',
                                ].join(' · '),
                              ),
                            if (ep.plot != null)
                              Text(
                                ep.plot!,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            if (ep.metadataAttribution !=
                                null)
                              Text(
                                '${ep.metadataAttribution} '
                                '· ${ep.metadataLicense ?? ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                          ],
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ep.metadataAttribution != null)
                        const Tooltip(
                          message:
                              'Zusätzliche '
                              'Episodeninformationen '
                              'von TVmaze',
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                          ),
                        ),
                      InkWell(
                        onTap: () async {
                          try {
                            await DownloadService.download(
                              url: ep.streamUrl,
                              filename:
                                  '${series.title}_S'
                                  '${season.number}E'
                                  '${ep.number}.mp4',
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).t(
                                      'download_failed',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        focusColor:
                            AppTheme.electricBlue
                                .withValues(alpha: 0.22),
                        borderRadius:
                            BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.download),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../providers/content_provider.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series.dart';
import '../widgets/voice_search_field.dart';

import 'series_screen.dart';
import 'player_screen.dart';

class MasterSearchScreen extends StatefulWidget {
  const MasterSearchScreen({super.key});

  @override
  State<MasterSearchScreen> createState() =>
      _MasterSearchScreenState();
}

class _MasterSearchScreenState
    extends State<MasterSearchScreen> {
  String _query = '';

  String _normalize(String value) {
    var s = value.toLowerCase().trim();

    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ñ': 'n',
      'ç': 'c',
      'ş': 's',
      'ğ': 'g',
      'ı': 'i',
      'İ': 'i',
      'ß': 'ss',
      'æ': 'ae',
      'œ': 'oe',
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ٱ': 'ا',
      'ى': 'ي',
      'ئ': 'ي',
      'ؤ': 'و',
      'ة': 'ه',
    };

    replacements.forEach(
      (from, to) => s = s.replaceAll(from, to),
    );

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _matches(Iterable<String?> values) {
    if (_query.trim().isEmpty) return false;

    final q = _normalize(_query);

    return values
        .whereType<String>()
        .any((value) => _normalize(value).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final l10n = AppLocalizations.of(context);

    final channels = content.channels
        .where((c) => _matches([c.name, c.category]))
        .toList();

    final movies = content.vodItems
        .where((v) => _matches([v.title, v.plot]))
        .toList();

    final series = content.series
        .where((s) => _matches([s.title, s.plot]))
        .toList();

    final hasQuery = _query.trim().isNotEmpty;
    final total =
        channels.length + movies.length + series.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('search_all')),
      ),
      body: FocusTraversalGroup(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20, 16, 20, 8,
              ),
              child: VoiceSearchField(
                appLanguageCode:
                    Localizations.localeOf(context)
                        .languageCode,
                onChanged: (value) {
                  setState(() => _query = value);
                },
              ),
            ),
            Expanded(
              child: !hasQuery
                  ? Center(
                      child: Text(
                        l10n.t('search_hint'),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : total == 0
                      ? Center(
                          child: Text(
                            l10n.t('no_results'),
                          ),
                        )
                      : ListView(
                          padding:
                              const EdgeInsets.only(
                            bottom: 24,
                          ),
                          children: [
                            if (channels.isNotEmpty)
                              _section(
                                l10n.t('nav_live'),
                                channels.length,
                              ),
                            ...channels.map(_channelTile),
                            if (movies.isNotEmpty)
                              _section(
                                l10n.t('nav_vod'),
                                movies.length,
                              ),
                            ...movies.map(_movieTile),
                            if (series.isNotEmpty)
                              _section(
                                l10n.t('nav_series'),
                                series.length,
                              ),
                            ...series.map(_seriesTile),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20, 18, 20, 6,
      ),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _channelTile(Channel channel) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      focusColor: Theme.of(context)
          .colorScheme
          .primary
          .withOpacity(0.14),
      leading: const Icon(Icons.live_tv),
      title: Text(channel.name),
      subtitle: Text(
        channel.category ?? l10n.t('nav_live'),
      ),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: channel,
            isLive: true,
          ),
        ),
      ),
    );
  }

  Widget _movieTile(VodItem movie) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      focusColor: Theme.of(context)
          .colorScheme
          .primary
          .withOpacity(0.14),
      leading: const Icon(Icons.movie),
      title: Text(movie.title),
      subtitle: Text(l10n.t('nav_vod')),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: movie.streamUrl,
            title: movie.title,
            contentId: movie.id,
          ),
        ),
      ),
    );
  }

  Widget _seriesTile(Series series) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      focusColor: Theme.of(context)
          .colorScheme
          .primary
          .withOpacity(0.14),
      leading: const Icon(Icons.video_library),
      title: Text(series.title),
      subtitle: Text(l10n.t('nav_series')),
      onTap: () => pushWithFocusRestore(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            series: series,
          ),
        ),
      ),
    );
  }
}

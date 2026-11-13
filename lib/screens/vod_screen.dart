import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/theme/app_theme.dart';
import '../models/vod_item.dart';
import '../providers/content_provider.dart';
import '../providers/locale_provider.dart';
import '../services/download_service.dart';
import '../widgets/favorite_toggle_button.dart';
import 'player_screen.dart';

String _vodText(BuildContext context, String key) {
  final language = context.watch<LocaleProvider>().locale.languageCode;
  const translations = <String, Map<String, String>>{
    'de': {'movies': 'Filme', 'all': 'Alle Filme', 'unknown': 'Ohne Genre', 'search': 'Filme suchen', 'categories': 'Kategorien', 'empty': 'Keine Filme vorhanden', 'noResults': 'Keine passenden Filme', 'download': 'Film herunterladen', 'downloading': 'Download läuft', 'failed': 'Download fehlgeschlagen', 'description': 'Beschreibung', 'director': 'Regie', 'cast': 'Besetzung', 'license': 'Lizenz', 'play': 'Abspielen', 'hours': 'Std.', 'minutes': 'Min.'},
    'tr': {'movies': 'Filmler', 'all': 'Tüm filmler', 'unknown': 'Tür belirtilmemiş', 'search': 'Film ara', 'categories': 'Kategoriler', 'empty': 'Film bulunamadı', 'noResults': 'Eşleşen film yok', 'download': 'Filmi indir', 'downloading': 'İndiriliyor', 'failed': 'İndirme başarısız', 'description': 'Açıklama', 'director': 'Yönetmen', 'cast': 'Oyuncular', 'license': 'Lisans', 'play': 'Oynat', 'hours': 'sa.', 'minutes': 'dk.'},
    'en': {'movies': 'Movies', 'all': 'All movies', 'unknown': 'No genre', 'search': 'Search movies', 'categories': 'Categories', 'empty': 'No movies available', 'noResults': 'No matching movies', 'download': 'Download movie', 'downloading': 'Downloading', 'failed': 'Download failed', 'description': 'Description', 'director': 'Director', 'cast': 'Cast', 'license': 'License', 'play': 'Play', 'hours': 'hr', 'minutes': 'min'},
    'ru': {'movies': 'Фильмы', 'all': 'Все фильмы', 'unknown': 'Без жанра', 'search': 'Поиск фильмов', 'categories': 'Категории', 'empty': 'Фильмов нет', 'noResults': 'Ничего не найдено', 'download': 'Скачать фильм', 'downloading': 'Загрузка', 'failed': 'Ошибка загрузки', 'description': 'Описание', 'director': 'Режиссёр', 'cast': 'Актёры', 'license': 'Лицензия', 'play': 'Смотреть', 'hours': 'ч', 'minutes': 'мин'},
    'pl': {'movies': 'Filmy', 'all': 'Wszystkie filmy', 'unknown': 'Bez gatunku', 'search': 'Szukaj filmów', 'categories': 'Kategorie', 'empty': 'Brak filmów', 'noResults': 'Brak wyników', 'download': 'Pobierz film', 'downloading': 'Pobieranie', 'failed': 'Błąd pobierania', 'description': 'Opis', 'director': 'Reżyser', 'cast': 'Obsada', 'license': 'Licencja', 'play': 'Odtwórz', 'hours': 'godz.', 'minutes': 'min'},
    'es': {'movies': 'Películas', 'all': 'Todas las películas', 'unknown': 'Sin género', 'search': 'Buscar películas', 'categories': 'Categorías', 'empty': 'No hay películas', 'noResults': 'Sin resultados', 'download': 'Descargar película', 'downloading': 'Descargando', 'failed': 'Error de descarga', 'description': 'Descripción', 'director': 'Dirección', 'cast': 'Reparto', 'license': 'Licencia', 'play': 'Reproducir', 'hours': 'h', 'minutes': 'min'},
    'fr': {'movies': 'Films', 'all': 'Tous les films', 'unknown': 'Sans genre', 'search': 'Rechercher des films', 'categories': 'Catégories', 'empty': 'Aucun film', 'noResults': 'Aucun résultat', 'download': 'Télécharger le film', 'downloading': 'Téléchargement', 'failed': 'Échec du téléchargement', 'description': 'Description', 'director': 'Réalisation', 'cast': 'Distribution', 'license': 'Licence', 'play': 'Lire', 'hours': 'h', 'minutes': 'min'},
    'ar': {'movies': 'أفلام', 'all': 'كل الأفلام', 'unknown': 'بدون نوع', 'search': 'ابحث عن فيلم', 'categories': 'الفئات', 'empty': 'لا توجد أفلام', 'noResults': 'لا توجد نتائج', 'download': 'تنزيل الفيلم', 'downloading': 'جارٍ التنزيل', 'failed': 'فشل التنزيل', 'description': 'الوصف', 'director': 'المخرج', 'cast': 'الممثلون', 'license': 'الترخيص', 'play': 'تشغيل', 'hours': 'س', 'minutes': 'د'},
  };
  return (translations[language] ?? translations['en']!)[key] ?? key;
}

class VodScreen extends StatefulWidget {
  const VodScreen({super.key});

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGenre;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _genre(VodItem item) {
    final value = item.genre?.trim();
    return value == null || value.isEmpty ? '' : value;
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ContentProvider>().vodItems;
    final counts = <String, int>{};
    for (final item in items) {
      final genre = _genre(item);
      counts[genre] = (counts[genre] ?? 0) + 1;
    }
    final genres = counts.keys.toList(growable: false);
    final selected = genres.contains(_selectedGenre) ? _selectedGenre : null;
    final filtered = items.where((item) {
      if (selected != null && _genre(item) != selected) return false;
      return item.title.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(_vodText(context, 'movies')),
      ),
      body: items.isEmpty
          ? Center(child: Text(_vodText(context, 'empty')))
          : LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 750;
              final sidebarWidth = constraints.maxWidth >= 1100 ? 260.0 : 210.0;
              final search = Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: _vodText(context, 'search'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty ? null : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
              );
              final genreList = ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  _GenreButton(
                    title: _vodText(context, 'all'), count: items.length,
                    selected: selected == null, autofocus: wide,
                    onTap: () => setState(() => _selectedGenre = null),
                  ),
                  for (final genre in genres)
                    _GenreButton(
                      title: genre.isEmpty ? _vodText(context, 'unknown') : genre,
                      count: counts[genre]!, selected: selected == genre,
                      onTap: () => setState(() => _selectedGenre = genre),
                    ),
                ],
              );
              final results = Column(children: [
                search,
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.category_outlined),
                        label: Text(selected == null
                            ? _vodText(context, 'all')
                            : selected.isEmpty ? _vodText(context, 'unknown') : selected),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (sheetContext) => SafeArea(
                            child: SizedBox(
                              height: MediaQuery.sizeOf(sheetContext).height * 0.65,
                              child: Column(children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(_vodText(context, 'categories'),
                                      style: Theme.of(context).textTheme.titleLarge),
                                ),
                                Expanded(child: ListView(children: [
                                  ListTile(
                                    title: Text(_vodText(context, 'all')),
                                    trailing: Text('${items.length}'),
                                    onTap: () { setState(() => _selectedGenre = null); Navigator.pop(sheetContext); },
                                  ),
                                  for (final genre in genres)
                                    ListTile(
                                      title: Text(genre.isEmpty ? _vodText(context, 'unknown') : genre),
                                      trailing: Text('${counts[genre]}'),
                                      onTap: () { setState(() => _selectedGenre = genre); Navigator.pop(sheetContext); },
                                    ),
                                ])),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(child: filtered.isEmpty
                    ? Center(child: Text(_vodText(context, 'noResults')))
                    : LayoutBuilder(builder: (context, size) {
                        final width = size.maxWidth;
                        final columns = width >= 1100 ? 6 : width >= 800 ? 5 : width >= 550 ? 4 : width >= 340 ? 3 : 2;
                        return FocusTraversalGroup(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.57,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _VodTile(
                              key: ValueKey(filtered[index].id),
                              item: filtered[index],
                              autofocus: index == 0 && !wide,
                            ),
                          ),
                        );
                      })),
              ]);
              if (!wide) return results;
              return Row(children: [
                SizedBox(
                  width: sidebarWidth,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_vodText(context, 'categories'),
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ),
                      Expanded(child: genreList),
                    ]),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: results),
              ]);
            }),
    );
  }
}

class _GenreButton extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;
  const _GenreButton({required this.title, required this.count, required this.selected,
    required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? AppTheme.electricBlue.withOpacity(0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(12),
        focusColor: AppTheme.electricBlue.withOpacity(0.3),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Expanded(child: Text(title, softWrap: true,
              style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal))),
            const SizedBox(width: 8),
            Text('$count', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    ),
  );
}

class _VodTile extends StatefulWidget {
  final VodItem item;
  final bool autofocus;
  const _VodTile({super.key, required this.item, this.autofocus = false});

  @override
  State<_VodTile> createState() => _VodTileState();
}

class _VodTileState extends State<_VodTile> {
  double _progress = 0;
  bool _downloading = false;

  Future<void> _download() async {
    setState(() { _downloading = true; _progress = 0; });
    try {
      await DownloadService.download(
        url: widget.item.streamUrl,
        filename: '${widget.item.title.replaceAll(RegExp(r"[^A-Za-z0-9]"), "_")}.mp4',
        onProgress: (received, total) {
          if (total > 0 && mounted) setState(() => _progress = received / total);
        },
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vodText(context, 'failed'))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      autofocus: widget.autofocus,
      focusColor: AppTheme.electricBlue.withOpacity(0.22),
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final language = context.read<LocaleProvider>().locale.languageCode;
        final enriched = await context.read<ContentProvider>().enrichVodMetadata(
          widget.item.id, language: language,
        );
        if (!context.mounted) return;
        await pushWithFocusRestore(context, MaterialPageRoute(
          builder: (_) => VodDetailScreen(item: enriched ?? widget.item),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.electricBlue.withOpacity(0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            widget.item.posterUrl != null && widget.item.posterUrl!.trim().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.item.posterUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.movie, size: 48),
                  )
                : const Icon(Icons.movie, size: 48),
            Positioned(left: 4, top: 4, child: FavoriteToggleButton(
              contentId: widget.item.id, contentType: 'vod', title: widget.item.title,
            )),
            Positioned(right: 4, top: 4, child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: _downloading ? _vodText(context, 'downloading') : _vodText(context, 'download'),
                focusColor: AppTheme.electricBlue.withOpacity(0.35),
                onPressed: _downloading ? null : _download,
                icon: Icon(_downloading ? Icons.downloading : Icons.download,
                  color: Colors.white, size: 20),
              ),
            )),
            if (_downloading && _progress > 0)
              Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(
                value: _progress.clamp(0.0, 1.0),
                backgroundColor: Colors.black45,
                color: AppTheme.electricBlue,
              )),
          ])),
          Padding(padding: const EdgeInsets.all(8), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              if (widget.item.releaseDate != null || widget.item.genre != null)
                Text([widget.item.releaseDate, widget.item.genre]
                    .whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
        ]),
      ),
    );
  }
}

class VodDetailScreen extends StatelessWidget {
  final VodItem item;
  const VodDetailScreen({super.key, required this.item});

  String _durationLabel(BuildContext context, int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0
        ? '$hours ${_vodText(context, 'hours')} $minutes ${_vodText(context, 'minutes')}'
        : '$minutes ${_vodText(context, 'minutes')}';
  }

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (item.releaseDate != null) item.releaseDate!,
      if (item.genre != null) item.genre!,
      if (item.durationSeconds != null) _durationLabel(context, item.durationSeconds!),
      if (item.ageRating != null) item.ageRating!,
      if (item.rating != null && item.rating! > 0) '★ ${item.rating!.toStringAsFixed(1)}',
    ];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(item.title),
        actions: [FavoriteToggleButton(contentId: item.id, contentType: 'vod', title: item.title)],
      ),
      body: ListView(children: [
        SizedBox(height: 260, child: Stack(fit: StackFit.expand, children: [
          if (item.backdropUrl != null && item.backdropUrl!.trim().isNotEmpty)
            CachedNetworkImage(imageUrl: item.backdropUrl!, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink()),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.08), Colors.black.withOpacity(0.88)],
          ))),
          Align(alignment: Alignment.bottomLeft, child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(item.title, style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
        ])),
        Padding(padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (facts.isNotEmpty) Wrap(spacing: 12, runSpacing: 8,
              children: facts.map((fact) => Chip(label: Text(fact))).toList()),
            if (item.plot != null && item.plot!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_vodText(context, 'description'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(item.plot!),
            ],
            if (item.director != null) ...[
              const SizedBox(height: 12),
              Text('${_vodText(context, 'director')}: ${item.director}'),
            ],
            if (item.cast != null) ...[
              const SizedBox(height: 8),
              Text('${_vodText(context, 'cast')}: ${item.cast}'),
            ],
            if (item.metadataAttribution != null) ...[
              const SizedBox(height: 12),
              Text(item.metadataAttribution!, style: Theme.of(context).textTheme.bodySmall),
              if (item.metadataSourceUrl != null)
                SelectableText(item.metadataSourceUrl!, style: Theme.of(context).textTheme.bodySmall),
              if (item.metadataLicense != null)
                Text('${_vodText(context, 'license')}: ${item.metadataLicense}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => pushWithFocusRestore(context, MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  streamUrl: item.streamUrl, title: item.title, contentId: item.id,
                ),
              )),
              icon: const Icon(Icons.play_arrow),
              label: Text(_vodText(context, 'play')),
            ),
          ],
        )),
      ]),
    );
  }
}

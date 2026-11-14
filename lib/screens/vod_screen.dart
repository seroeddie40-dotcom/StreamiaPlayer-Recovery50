
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
  final language =
      context.watch<LocaleProvider>().locale.languageCode;

  const translations = <String, Map<String, String>>{
    'de': {
      'movies': 'Filme',
      'all': 'Alle Filme',
      'unknown': 'Ohne Genre',
      'search': 'Filme suchen',
      'categories': 'Kategorien',
      'empty': 'Keine Filme vorhanden',
      'noResults': 'Keine passenden Filme',
      'download': 'Film herunterladen',
      'downloading': 'Download läuft',
      'failed': 'Download fehlgeschlagen',
      'description': 'Beschreibung',
      'director': 'Regie',
      'cast': 'Besetzung',
      'license': 'Lizenz',
      'play': 'Abspielen',
      'unavailable': 'Keine gültige Filmadresse vorhanden',
      'hours': 'Std.',
      'minutes': 'Min.',
    },
    'tr': {
      'movies': 'Filmler',
      'all': 'Tüm filmler',
      'unknown': 'Tür belirtilmemiş',
      'search': 'Film ara',
      'categories': 'Kategoriler',
      'empty': 'Film bulunamadı',
      'noResults': 'Eşleşen film yok',
      'download': 'Filmi indir',
      'downloading': 'İndiriliyor',
      'failed': 'İndirme başarısız',
      'description': 'Açıklama',
      'director': 'Yönetmen',
      'cast': 'Oyuncular',
      'license': 'Lisans',
      'play': 'Oynat',
      'unavailable': 'Geçerli film bağlantısı bulunamadı',
      'hours': 'sa.',
      'minutes': 'dk.',
    },
    'en': {
      'movies': 'Movies',
      'all': 'All movies',
      'unknown': 'No genre',
      'search': 'Search movies',
      'categories': 'Categories',
      'empty': 'No movies available',
      'noResults': 'No matching movies',
      'download': 'Download movie',
      'downloading': 'Downloading',
      'failed': 'Download failed',
      'description': 'Description',
      'director': 'Director',
      'cast': 'Cast',
      'license': 'License',
      'play': 'Play',
      'unavailable': 'No valid movie stream address',
      'hours': 'hr',
      'minutes': 'min',
    },
    'ru': {
      'movies': 'Фильмы',
      'all': 'Все фильмы',
      'unknown': 'Без жанра',
      'search': 'Поиск фильмов',
      'categories': 'Категории',
      'empty': 'Фильмов нет',
      'noResults': 'Ничего не найдено',
      'download': 'Скачать фильм',
      'downloading': 'Загрузка',
      'failed': 'Ошибка загрузки',
      'description': 'Описание',
      'director': 'Режиссёр',
      'cast': 'Актёры',
      'license': 'Лицензия',
      'play': 'Смотреть',
      'unavailable': 'Нет действительной ссылки на фильм',
      'hours': 'ч',
      'minutes': 'мин',
    },
    'pl': {
      'movies': 'Filmy',
      'all': 'Wszystkie filmy',
      'unknown': 'Bez gatunku',
      'search': 'Szukaj filmów',
      'categories': 'Kategorie',
      'empty': 'Brak filmów',
      'noResults': 'Brak wyników',
      'download': 'Pobierz film',
      'downloading': 'Pobieranie',
      'failed': 'Błąd pobierania',
      'description': 'Opis',
      'director': 'Reżyser',
      'cast': 'Obsada',
      'license': 'Licencja',
      'play': 'Odtwórz',
      'unavailable': 'Brak prawidłowego adresu filmu',
      'hours': 'godz.',
      'minutes': 'min',
    },
    'es': {
      'movies': 'Películas',
      'all': 'Todas las películas',
      'unknown': 'Sin género',
      'search': 'Buscar películas',
      'categories': 'Categorías',
      'empty': 'No hay películas',
      'noResults': 'Sin resultados',
      'download': 'Descargar película',
      'downloading': 'Descargando',
      'failed': 'Error de descarga',
      'description': 'Descripción',
      'director': 'Dirección',
      'cast': 'Reparto',
      'license': 'Licencia',
      'play': 'Reproducir',
      'unavailable': 'No hay una dirección válida para la película',
      'hours': 'h',
      'minutes': 'min',
    },
    'fr': {
      'movies': 'Films',
      'all': 'Tous les films',
      'unknown': 'Sans genre',
      'search': 'Rechercher des films',
      'categories': 'Catégories',
      'empty': 'Aucun film',
      'noResults': 'Aucun résultat',
      'download': 'Télécharger le film',
      'downloading': 'Téléchargement',
      'failed': 'Échec du téléchargement',
      'description': 'Description',
      'director': 'Réalisation',
      'cast': 'Distribution',
      'license': 'Licence',
      'play': 'Lire',
      'unavailable': 'Aucune adresse de film valide',
      'hours': 'h',
      'minutes': 'min',
    },
    'ar': {
      'movies': 'أفلام',
      'all': 'كل الأفلام',
      'unknown': 'بدون نوع',
      'search': 'ابحث عن فيلم',
      'categories': 'الفئات',
      'empty': 'لا توجد أفلام',
      'noResults': 'لا توجد نتائج',
      'download': 'تنزيل الفيلم',
      'downloading': 'جارٍ التنزيل',
      'failed': 'فشل التنزيل',
      'description': 'الوصف',
      'director': 'المخرج',
      'cast': 'الممثلون',
      'license': 'الترخيص',
      'play': 'تشغيل',
      'unavailable': 'لا يوجد رابط صالح للفيلم',
      'hours': 'س',
      'minutes': 'د',
    },
  };

  return (translations[language] ?? translations['en']!)[key] ??
      key;
}

bool _validVodUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'rtsp' ||
          uri.scheme == 'rtmp') &&
      uri.host.isNotEmpty;
}

void _showVodError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_vodText(context, 'unavailable')),
    ),
  );
}

class VodScreen extends StatefulWidget {
  const VodScreen({super.key});

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String? _selectedGenre;
  bool _folderFocusExpanded = false;
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

    final selected =
        genres.contains(_selectedGenre) ? _selectedGenre : null;

    final filtered = items.where((item) {
      if (selected != null && _genre(item) != selected) {
        return false;
      }

      return item.title
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_vodText(context, 'movies')),
      ),
      body: items.isEmpty
          ? Center(child: Text(_vodText(context, 'empty')))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 750;
                final sidebarWidth =
                    constraints.maxWidth >= 1100 ? 340.0 : 285.0;

                final search = Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: _vodText(context, 'search'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                  ),
                );

                final genreList = ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  children: [
                    _GenreButton(
                      title: _vodText(context, 'all'),
                      count: items.length,
                      selected: selected == null,
                      autofocus: wide,
                      onTap: () =>
                          setState(() => _selectedGenre = null),
                    ),
                    for (final genre in genres)
                      _GenreButton(
                        title: genre.isEmpty
                            ? _vodText(context, 'unknown')
                            : genre,
                        count: counts[genre]!,
                        selected: selected == genre,
                        onTap: () =>
                            setState(() => _selectedGenre = genre),
                      ),
                  ],
                );

                final results = Column(
                  children: [
                    search,
                    if (!wide)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.category_outlined,
                            ),
                            label: Text(
                              selected == null
                                  ? _vodText(context, 'all')
                                  : selected.isEmpty
                                      ? _vodText(context, 'unknown')
                                      : selected,
                            ),
                            onPressed: () =>
                                showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (sheetContext) => SafeArea(
                                child: SizedBox(
                                  height: MediaQuery.sizeOf(
                                        sheetContext,
                                      ).height *
                                      0.65,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.all(16),

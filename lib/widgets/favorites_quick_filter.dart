import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import '../providers/locale_provider.dart';

import '../services/profile_favorite_outbox.dart';

// Favorites are profile-scoped. Keep the catalog permission filter
// in the calling screen, independently of this optional membership filter.
final favoritesRevision = ValueNotifier<int>(0);

mixin FavoritesQuickFilter<T extends StatefulWidget> on State<T> {
  String get sortArea;
  bool favoritesOnly = false;
  Set<String> _favoriteIds = {};
  String? _favoriteScope;
  int _request = 0;
  int _seenSyncRevision = -1;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    favoritesRevision.addListener(_favoritesChanged);
  }

  @override
  void dispose() {
    favoritesRevision.removeListener(_favoritesChanged);
    ++_request;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final family = context.watch<FamilySessionProvider>();
    final profile = family.activeProfile;
    final source = context.watch<ContentProvider>().sourceKey;
    final scope = profile == null ? null : '${profile.accountUserId}:${profile.id}:$source';
    final syncRevision = family.profileSyncRevision;
    if (scope == _favoriteScope) {
      if (syncRevision != _seenSyncRevision && favoritesOnly) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && favoritesOnly && _favoriteScope == scope && !_loading) _loadFavorites();
        });
      }
      _seenSyncRevision = syncRevision;
      return;
    }
    _seenSyncRevision = syncRevision;
    _favoriteScope = scope;
    ++_request;
    favoritesOnly = false;
    _favoriteIds = {};
    _loading = false;
    _failed = false;
  }

  bool matchesFavorite(String id) => !favoritesOnly || (!_loading && !_failed && _favoriteIds.contains(id));

  void _favoritesChanged() {
    if (mounted && favoritesOnly) _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final request = ++_request;
    final source = context.read<ContentProvider>().sourceKey;
    setState(() { _loading = true; _failed = false; _favoriteIds = {}; });
    try {
      if (!SupabaseConfig.isConfigured) throw StateError('Unavailable');
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final family = context.read<FamilySessionProvider>();
      final profile = family.activeProfile;
      if (!family.isReady || profile == null || profile.accountUserId != user?.id) throw StateError('Unavailable');
      if (user == null) throw StateError('Unavailable');
      final rows = await ProfileFavoriteOutbox.load(client,user.id,profile.id,family.parentAccessToken,() => mounted && request == _request && family.isReady && family.activeProfile?.id == profile.id);
      final ids = rows.where((r) => r['source_key'] == source && r['content_type'] == sortArea).map((r) => r['content_id'].toString()).toSet();
      if (mounted && request == _request) setState(() { _favoriteIds = ids; _loading = false; });
    } catch (_) {
      if (mounted && request == _request) setState(() { _failed = true; _loading = false; });
    }
  }

  Widget favoritesButton() {
    const labels = <String, List<String>>{
      'de': ['Favoriten', 'Alle Inhalte', 'Favoriten erneut laden'],
      'tr': ['Favoriler', 'Tüm içerikler', 'Favorileri yeniden yükle'],
      'en': ['Favorites', 'All content', 'Retry favorites'],
      'ru': ['Избранное', 'Все материалы', 'Обновить избранное'],
      'pl': ['Ulubione', 'Wszystkie treści', 'Wczytaj ulubione ponownie'],
      'es': ['Favoritos', 'Todo el contenido', 'Recargar favoritos'],
      'fr': ['Favoris', 'Tous les contenus', 'Recharger les favoris'],
      'ar': ['المفضلة', 'كل المحتوى', 'إعادة تحميل المفضلة'],
    };
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final text = labels[lang] ?? labels['en']!;
    return IconButton(
      focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.35),
      tooltip: text[_failed ? 2 : favoritesOnly ? 1 : 0],
      onPressed: _favoriteScope == null ? null : () {
        if (_failed) { _loadFavorites(); return; }
        setState(() => favoritesOnly = !favoritesOnly);
        if (favoritesOnly) { _loadFavorites(); }
        else { ++_request; setState(() { _loading = false; _failed = false; }); }
      },
      color: favoritesOnly ? Theme.of(context).colorScheme.primary : null,
      icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_failed ? Icons.refresh : favoritesOnly ? Icons.favorite : Icons.favorite_border),
    );
  }
}

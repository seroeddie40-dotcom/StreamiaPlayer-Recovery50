import '../core/platform/device_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import 'favorites_quick_filter.dart';
import '../config/supabase_config.dart';
import '../services/profile_favorite_outbox.dart';

/// Account-synced favorite toggle. The source key is a one-way hash, never a URL or credential.
class FavoriteToggleButton extends StatefulWidget {
  final String contentId;
  final String contentType;
  final String title;
  const FavoriteToggleButton({super.key, required this.contentId,
    required this.contentType, required this.title});

  @override
  State<FavoriteToggleButton> createState() => FavoriteToggleButtonState();
}

class FavoriteToggleButtonState extends State<FavoriteToggleButton> {
  bool? _favorite;
  bool _busy = false;
  String? _loadedKey;
  int _seenSyncRevision = -1;
  Future<bool>? _loadFuture;

  String _message(String key) {
    final language = Localizations.localeOf(context).languageCode;
    const translations = <String, Map<String, String>>{
      'login': {
        'de': 'Bitte anmelden, um Favoriten zu synchronisieren.',
        'tr': 'Favorileri eşitlemek için giriş yapın.',
        'en': 'Sign in to sync favorites.',
        'ru': 'Войдите, чтобы синхронизировать избранное.',
        'pl': 'Zaloguj się, aby synchronizować ulubione.',
        'es': 'Inicia sesión para sincronizar favoritos.',
        'fr': 'Connectez-vous pour synchroniser les favoris.',
        'ar': 'سجّل الدخول لمزامنة المفضلة.',
      },
      'failed': {
        'de': 'Favorit konnte nicht gespeichert werden',
        'tr': 'Favori kaydedilemedi',
        'en': 'Could not save favorite',
        'ru': 'Не удалось сохранить избранное',
        'pl': 'Nie udało się zapisać ulubionego',
        'es': 'No se pudo guardar el favorito',
        'fr': 'Impossible d’enregistrer le favori',
        'ar': 'تعذّر حفظ المفضلة',
      },
      'signIn': {
        'de': 'Zum Synchronisieren anmelden',
        'tr': 'Eşitlemek için giriş yapın',
        'en': 'Sign in to sync',
        'ru': 'Войдите для синхронизации',
        'pl': 'Zaloguj się, aby synchronizować',
        'es': 'Inicia sesión para sincronizar',
        'fr': 'Connectez-vous pour synchroniser',
        'ar': 'سجّل الدخول للمزامنة',
      },
      'remove': {
        'de': 'Aus Favoriten entfernen',
        'tr': 'Favorilerden kaldır',
        'en': 'Remove from favorites',
        'ru': 'Удалить из избранного',
        'pl': 'Usuń z ulubionych',
        'es': 'Quitar de favoritos',
        'fr': 'Retirer des favoris',
        'ar': 'إزالة من المفضلة',
      },
      'add': {
        'de': 'Zu Favoriten hinzufügen',
        'tr': 'Favorilere ekle',
        'en': 'Add to favorites',
        'ru': 'Добавить в избранное',
        'pl': 'Dodaj do ulubionych',
        'es': 'Añadir a favoritos',
        'fr': 'Ajouter aux favoris',
        'ar': 'إضافة إلى المفضلة',
      },
    };
    final values = translations[key]!;
    return values[language] ?? values['en']!;
  }

  Future<bool> _read(String sourceKey, String profileId) async {
    if (!SupabaseConfig.isConfigured) return false;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;
    final token = context.read<FamilySessionProvider>().parentAccessToken;
    final pending = await ProfileFavoriteOutbox.pendingValue(user.id, profileId, sourceKey, widget.contentType, widget.contentId);
    if (pending != null) return pending;
    final family = context.read<FamilySessionProvider>();
    final rows = await ProfileFavoriteOutbox.load(client,user.id,profileId,token,() => mounted && family.isReady && family.activeProfile?.id == profileId);
    return rows.any((r) => r['source_key'] == sourceKey && r['content_type'] == widget.contentType && r['content_id'].toString() == widget.contentId);

  }

  Future<void> _toggle(String sourceKey, String profileId) async {
    if (_busy || !SupabaseConfig.isConfigured) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message('login'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final current = _favorite ?? await _read(sourceKey, profileId);
      if (!mounted || context.read<FamilySessionProvider>().activeProfile?.id != profileId || client.auth.currentUser?.id != user.id || context.read<ContentProvider>().sourceKey != sourceKey) return;
      final family = context.read<FamilySessionProvider>();
      final token = family.parentAccessToken;
      final label = context.read<ContentProvider>().sourceLabel;
      await ProfileFavoriteOutbox.enqueue(user.id, profileId, sourceKey, widget.contentType, widget.contentId, widget.title, label ?? '', !current);
      await ProfileFavoriteOutbox.flush(client, user.id, profileId, token, () => family.isReady && family.activeProfile?.id == profileId && family.parentAccessToken == token);
      if (!mounted || family.activeProfile?.id != profileId || client.auth.currentUser?.id != user.id || context.read<ContentProvider>().sourceKey != sourceKey) return;
      final confirmed = await _read(sourceKey, profileId);
      if (!mounted || family.activeProfile?.id != profileId || client.auth.currentUser?.id != user.id || context.read<ContentProvider>().sourceKey != sourceKey) return;
      setState(() => _favorite = confirmed);
      favoritesRevision.value++;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_message('failed')}: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Used by the focused TV catalog card on a long OK press. The same
  /// profile-scoped outbox and authorization checks as the touch button apply.
  Future<void> toggleFromRemote() async {
    if (!mounted || _busy) return;
    final family = context.read<FamilySessionProvider>();
    final profile = family.activeProfile;
    if (!family.isReady || profile == null) return;
    await _toggle(context.read<ContentProvider>().sourceKey, profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final sourceKey = context.watch<ContentProvider>().sourceKey;
    final family = context.watch<FamilySessionProvider>();
    final profile = family.activeProfile;
    if (!family.isReady || profile == null) return const SizedBox.shrink();
    final profileId = profile.id;
    final key = '${profile.accountUserId}:$profileId:$sourceKey:${widget.contentType}:${widget.contentId}';
    if (_loadedKey != key || (!_busy && _seenSyncRevision != family.profileSyncRevision)) {
      _seenSyncRevision = family.profileSyncRevision;
      _loadedKey = key;
      _favorite = null;
      _loadFuture = _read(sourceKey, profileId);
    }
    if (!SupabaseConfig.isConfigured || Supabase.instance.client.auth.currentUser == null) {
      return ExcludeFocus(
        excluding: DeviceLayout.isTelevision,
        child: IconButton(
        tooltip: _message('signIn'),
        onPressed: null,
        icon: const Icon(Icons.favorite_border),
        ),
      );
    }
    return FutureBuilder<bool>(
      future: _favorite == null ? (_loadFuture ??= _read(sourceKey, profileId)) : Future.value(_favorite),
      builder: (context, snapshot) {
        final value = _favorite ?? snapshot.data ?? false;
        return ExcludeFocus(
          excluding: DeviceLayout.isTelevision,
          child: IconButton(
          focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.35),
          tooltip: _message(value ? 'remove' : 'add'),
          onPressed: _busy || !snapshot.hasData && _favorite == null ? null : () => _toggle(sourceKey, profileId),
          icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(value ? Icons.favorite : Icons.favorite_border,
                  color: value ? Colors.redAccent : null),
          ),
        );
      },
    );
  }
}

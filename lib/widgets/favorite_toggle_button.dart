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
  State<FavoriteToggleButton> createState() => _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends State<FavoriteToggleButton> {
  bool? _favorite;
  bool _busy = false;
  String? _loadedKey;
  int _seenSyncRevision = -1;
  Future<bool>? _loadFuture;

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
        const SnackBar(content: Text('Bitte anmelden, um Favoriten zu synchronisieren.')));
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
        SnackBar(content: Text('Favorit konnte nicht gespeichert werden: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        tooltip: 'Zum Synchronisieren anmelden',
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
          tooltip: value ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen',
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

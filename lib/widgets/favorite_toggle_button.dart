import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/content_provider.dart';
import '../config/supabase_config.dart';

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
  Future<bool>? _loadFuture;

  Future<bool> _read(String sourceKey) async {
    if (!SupabaseConfig.isConfigured) return false;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;
    final row = await client.from('favorites').select('id')
      .eq('user_id', user.id).eq('content_type', widget.contentType)
      .eq('content_id', widget.contentId).eq('source_key', sourceKey)
      .maybeSingle();
    return row != null;
  }

  Future<void> _toggle(String sourceKey) async {
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
      final current = _favorite ?? await _read(sourceKey);
      if (current) {
        await client.from('favorites').delete().eq('user_id', user.id)
          .eq('content_type', widget.contentType).eq('content_id', widget.contentId)
          .eq('source_key', sourceKey);
      } else {
        await client.from('favorites').upsert({
          'user_id': user.id,
          'playlist_id': null,
          'content_id': widget.contentId,
          'content_type': widget.contentType,
          'title': widget.title,
          'source_key': sourceKey,
          'source_label': context.read<ContentProvider>().sourceLabel,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,content_type,source_key,content_id');
      }
      if (mounted) setState(() => _favorite = !current);
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
    if (_loadedKey != sourceKey) {
      _loadedKey = sourceKey;
      _favorite = null;
      _loadFuture = _read(sourceKey);
    }
    if (!SupabaseConfig.isConfigured || Supabase.instance.client.auth.currentUser == null) {
      return IconButton(
        tooltip: 'Zum Synchronisieren anmelden',
        onPressed: null,
        icon: const Icon(Icons.favorite_border),
      );
    }
    return FutureBuilder<bool>(
      future: _favorite == null ? (_loadFuture ??= _read(sourceKey)) : Future.value(_favorite),
      builder: (context, snapshot) {
        final value = _favorite ?? snapshot.data ?? false;
        return IconButton(
          tooltip: value ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen',
          onPressed: _busy || !snapshot.hasData && _favorite == null ? null : () => _toggle(sourceKey),
          icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(value ? Icons.favorite : Icons.favorite_border,
                  color: value ? Colors.redAccent : null),
        );
      },
    );
  }
}

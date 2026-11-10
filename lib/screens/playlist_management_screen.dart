import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../services/playlist_switch_service.dart';
import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../models/playlist_profile.dart';
import '../services/playlist_profile_store.dart';
import 'setup_screen.dart';

class PlaylistManagementScreen extends StatefulWidget {
  const PlaylistManagementScreen({super.key});

  @override
  State<PlaylistManagementScreen> createState() => _PlaylistManagementScreenState();
}

class _PlaylistManagementScreenState extends State<PlaylistManagementScreen> {
  final _store = PlaylistProfileStore();
  List<PlaylistProfile> _profiles = [];
  bool _loading = true;
  String? _switchingKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _store.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _persist(List<PlaylistProfile> updated) async {
    setState(() => _profiles = updated);
    await _store.saveAll(updated);
  }

  Future<void> _edit(PlaylistProfile profile) async {
    final name = TextEditingController(text: profile.displayName);
    final folder = TextEditingController(text: profile.folderName);
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('playlist_edit')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('playlist_display_name'))),
          const SizedBox(height: 12),
          TextField(controller: folder, textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('playlist_folder'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppLocalizations.of(context).t('playlist_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, (name.text.trim(), folder.text.trim())),
            child: Text(AppLocalizations.of(context).t('playlist_save'))),
        ],
      ),
    );
    name.dispose();
    folder.dispose();
    if (result == null) return;
    final updated = _profiles.map((p) => p.sourceKey == profile.sourceKey
      ? p.copyWith(displayName: result.$1.isEmpty ? p.displayName : result.$1, folderName: result.$2)
      : p).toList();
    await _persist(updated);
  }

  Future<void> _activate(PlaylistProfile profile) async {
    setState(() => _switchingKey = profile.sourceKey);
    try {
      final activated = await PlaylistSwitchService().activate(profile, context.read<ContentProvider>());
      await _load();
      if (!activated) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.displayName} · ${AppLocalizations.of(context).t('playlist_active')}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _switchingKey = null);
    }
  }

  Future<void> _toggleVisibility(PlaylistProfile profile, bool visible) async {
    final updated = _profiles.map((p) => p.sourceKey == profile.sourceKey ? p.copyWith(isVisible: visible) : p).toList();
    await _persist(updated);
  }

  Future<void> _move(PlaylistProfile profile, int delta) async {
    final current = _profiles.indexWhere((p) => p.sourceKey == profile.sourceKey);
    final target = current + delta;
    if (current < 0 || target < 0 || target >= _profiles.length) return;
    final updated = List<PlaylistProfile>.from(_profiles);
    final item = updated.removeAt(current);
    updated.insert(target, item);
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(sortOrder: i);
    }
    await _persist(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = context.watch<ContentProvider>();
    final grouped = <String, List<PlaylistProfile>>{};
    for (final profile in _profiles) {
      final folder = profile.folderName.trim().isEmpty ? l10n.t('playlist_no_folder') : profile.folderName.trim();
      grouped.putIfAbsent(folder, () => []).add(profile);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('playlist_management'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await pushWithFocusRestore<bool>(context,
            MaterialPageRoute<bool>(builder: (_) => const SetupScreen(returnToPreviousOnSuccess: true)));
          if (added == true) await _load();
        },
        icon: const Icon(Icons.add), label: Text(l10n.t('playlist_add')),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _profiles.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.t('playlist_empty'))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
              children: [
                Text(l10n.t('playlist_visibility_hint'), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Row(children: [const Icon(Icons.folder_outlined), const SizedBox(width: 8),
                      Text(entry.key, style: Theme.of(context).textTheme.titleMedium)]),
                  ),
                  for (final profile in entry.value)
                    Card(
                      child: ListTile(
                        autofocus: _profiles.first.sourceKey == profile.sourceKey,
                        focusColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                        leading: Icon(profile.type == 'xtream' ? Icons.dns_outlined : Icons.playlist_play),
                        title: Text(profile.displayName),
                        subtitle: Text('${profile.type.toUpperCase()}${(content.isLoaded ? content.sourceKey == profile.sourceKey : profile.isActive) ? ' · ${l10n.t('playlist_active')}' : ''}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: l10n.t('playlist_activate'),
                            onPressed: (content.isLoaded ? content.sourceKey == profile.sourceKey : profile.isActive) || _switchingKey != null ? null : () => _activate(profile),
                            icon: _switchingKey == profile.sourceKey
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon((content.isLoaded ? content.sourceKey == profile.sourceKey : profile.isActive) ? Icons.check_circle : Icons.play_circle_outline),
                          ),
                          PopupMenuButton<String>(
                            tooltip: l10n.t('playlist_edit'),
                            onSelected: (action) {
                              if (action == 'up') _move(profile, -1);
                              if (action == 'down') _move(profile, 1);
                              if (action == 'edit') _edit(profile);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'up', child: Text(l10n.t('playlist_move_up'))),
                              PopupMenuItem(value: 'down', child: Text(l10n.t('playlist_move_down'))),
                              PopupMenuItem(value: 'edit', child: Text(l10n.t('playlist_edit'))),
                            ],
                            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_vert)),
                          ),
                          Switch(value: profile.isVisible, onChanged: (value) => _toggleVisibility(profile, value)),
                        ]),
                        onTap: () => _edit(profile),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(l10n.t('playlist_security_note'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}

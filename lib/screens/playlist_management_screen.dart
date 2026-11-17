
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import '../services/playlist_switch_service.dart';
import '../services/playlist_refresh_schedule.dart';
import '../core/focus_navigation.dart';
import '../core/platform/device_layout.dart';
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
  Map<String, int> _refreshHours = {};
  String? _switchingKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _store.load();
    final hours = <String, int>{};
    for (final profile in profiles) {
      hours[profile.sourceKey] = await PlaylistRefreshSchedule.hours(profile.sourceKey);
    }
    if (!mounted) return;
    setState(() {
      _refreshHours = hours;
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _setRefreshHours(PlaylistProfile profile, int value) async {
    if (_switchingKey != null || context.read<FamilySessionProvider>().isChild) return;
    setState(() => _switchingKey = profile.sourceKey);
    try {
      await PlaylistRefreshSchedule.setHours(profile.sourceKey, value);
      if (mounted) setState(() => _refreshHours[profile.sourceKey] = value);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('playlist_refresh_error'))));
    } finally {
      if (mounted) setState(() => _switchingKey = null);
    }
  }

  Future<void> _persist(List<PlaylistProfile> updated) async {
    setState(() => _profiles = updated);
    await _store.saveAll(updated);
  }

  Future<void> _edit(PlaylistProfile profile) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _PlaylistEditDialog(profile: profile),
    );
    if (!mounted || result == null) return;
    final updated = _profiles.map((p) => p.sourceKey == profile.sourceKey
      ? p.copyWith(displayName: result.$1.isEmpty ? p.displayName : result.$1, folderName: result.$2)
      : p).toList();
    await _persist(updated);
  }

  Future<void> _activate(PlaylistProfile profile, {bool refresh = false}) async {
    if (_switchingKey != null) return;
    if (refresh && context.read<FamilySessionProvider>().isChild) return;
    setState(() => _switchingKey = profile.sourceKey);
    try {
      final service = PlaylistSwitchService();
      final content = context.read<ContentProvider>();
      final activated = await (refresh ? service.refresh(profile, content) : service.activate(profile, content));
      await _load();
      if (!activated) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.displayName} · ${AppLocalizations.of(context).t(refresh ? 'playlist_refresh_success' : 'playlist_active')}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(refresh ? AppLocalizations.of(context).t('playlist_refresh_error') : error.toString())));
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
    final canRefresh = !context.watch<FamilySessionProvider>().isChild;
    final grouped = <String, List<PlaylistProfile>>{};
    for (final profile in _profiles) {
      final folder = profile.folderName.trim().isEmpty ? l10n.t('playlist_no_folder') : profile.folderName.trim();
      grouped.putIfAbsent(folder, () => []).add(profile);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('playlist_management'))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: FilledButton.icon(
        onPressed: _switchingKey != null ? null : () async {
          final added = await pushWithFocusRestore<bool>(context,
            MaterialPageRoute<bool>(builder: (_) => const SetupScreen(returnToPreviousOnSuccess: true)));
          if (added == true) await _load();
        },
        icon: const Icon(Icons.add), label: Text(l10n.t('playlist_add')),
          ),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _profiles.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.t('playlist_empty'))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                      child: Column(children: [
                      ListTile(
                        autofocus: DeviceLayout.isTelevision &&
                            _profiles.first.sourceKey == profile.sourceKey,
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
                            enabled: _switchingKey == null,
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
                          Switch(value: profile.isVisible, onChanged: _switchingKey != null ? null : (value) => _toggleVisibility(profile, value)),
                        ]),
                        onTap: _switchingKey != null ? null : () => _edit(profile),
                      ),
                      if (canRefresh)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('${profile.sourceKey}:${_refreshHours[profile.sourceKey]}'),
                            initialValue: _refreshHours[profile.sourceKey] ?? PlaylistRefreshSchedule.defaultHours,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.t('playlist_auto_refresh')),
                            items: [for (final hours in PlaylistRefreshSchedule.intervals)
                              DropdownMenuItem(value: hours, child: Text(l10n.t('playlist_interval_$hours')))],
                            onChanged: _switchingKey != null ? null : (value) {
                              if (value != null) _setRefreshHours(profile, value);
                            },
                          ),
                        ),
                      if (canRefresh && (content.isLoaded ? content.sourceKey == profile.sourceKey : profile.isActive))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: _switchingKey != null ? null : () => _activate(profile, refresh: true),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.t(_switchingKey == profile.sourceKey ? 'playlist_refreshing' : 'playlist_refresh')),
                            )),
                          ]),
                        ),
                      ]),
                    ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _PlaylistEditDialog extends StatefulWidget {
  const _PlaylistEditDialog({required this.profile});
  final PlaylistProfile profile;

  @override
  State<_PlaylistEditDialog> createState() => _PlaylistEditDialogState();
}

class _PlaylistEditDialogState extends State<_PlaylistEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _folder;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _folder = TextEditingController(text: widget.profile.folderName);
  }

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(l10n.t('playlist_edit')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(labelText: l10n.t('playlist_display_name'))),
        const SizedBox(height: 8),
        TextField(controller: _folder, textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(labelText: l10n.t('playlist_folder'))),
      ]),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('playlist_cancel'))),
        FilledButton(onPressed: () => Navigator.of(context).pop((_name.text.trim(), _folder.text.trim())),
          child: Text(l10n.t('playlist_save'))),
      ],
    );
  }
}

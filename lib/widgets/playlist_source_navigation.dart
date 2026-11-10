import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_localizations.dart';
import '../models/playlist_profile.dart';
import '../providers/content_provider.dart';
import '../services/playlist_profile_store.dart';
import '../services/playlist_switch_service.dart';

/// Compact source/folder switcher shown on the dashboard. Hidden playlists are
/// intentionally omitted here but remain available in Playlist Management.
class PlaylistSourceNavigation extends StatefulWidget {
  const PlaylistSourceNavigation({super.key});

  @override
  State<PlaylistSourceNavigation> createState() =>
      _PlaylistSourceNavigationState();
}

class _PlaylistSourceNavigationState extends State<PlaylistSourceNavigation> {
  final PlaylistProfileStore _store = PlaylistProfileStore();
  List<PlaylistProfile> _profiles = const [];
  bool _loading = true;
  String? _switching;

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

  Future<void> _activate(PlaylistProfile profile) async {
    final content = context.read<ContentProvider>();
    final alreadyActive = content.isLoaded
        ? content.sourceKey == profile.sourceKey
        : profile.isActive;
    if (alreadyActive || _switching != null) return;

    setState(() => _switching = profile.sourceKey);
    try {
      final activated = await PlaylistSwitchService().activate(profile, content);
      await _load();
      if (!activated) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${profile.displayName} · '
            '${AppLocalizations.of(context).t('playlist_active')}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _profiles.where((profile) => profile.isVisible).toList();
    final folders = <String, List<PlaylistProfile>>{};

    for (final profile in visible) {
      final folder = profile.folderName.trim().isEmpty
          ? l10n.t('playlist_no_folder')
          : profile.folderName.trim();
      folders.putIfAbsent(folder, () => []).add(profile);
    }

    if (!_loading && visible.isEmpty) return const SizedBox.shrink();

    final compact = MediaQuery.sizeOf(context).width < 600;
    final content = context.watch<ContentProvider>();

    return Card(
      margin: EdgeInsets.fromLTRB(
        compact ? 16 : 48,
        8,
        compact ? 16 : 48,
        4,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_play),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('playlist_source_navigation'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (!_loading && folders.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: compact ? 260 : 320,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in folders.entries)
                      ExpansionTile(
                        dense: true,
                        initiallyExpanded: folders.length == 1,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(entry.key),
                        children: [
                          for (final profile in entry.value)
                            Builder(
                              builder: (context) {
                                final isActive = content.isLoaded
                                    ? content.sourceKey == profile.sourceKey
                                    : profile.isActive;

                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  autofocus: false,
                                  focusColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(.16),
                                  leading: Icon(
                                    isActive
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                  ),
                                  title: Text(
                                    profile.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(profile.type.toUpperCase()),
                                  trailing: _switching == profile.sourceKey
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : isActive
                                          ? Text(l10n.t('playlist_active'))
                                          : null,
                                  onTap: isActive
                                      ? null
                                      : () => _activate(profile),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

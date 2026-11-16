import 'package:flutter/material.dart';

import '../models/family_profile.dart';
import '../models/playlist_profile.dart';

import '../services/family_pin_service.dart';
import '../services/family_profile_service.dart';
import '../services/family_profile_management_service.dart';
import '../services/family_category_catalog_service.dart';
import '../services/family_playlist_category_service.dart';

class FamilyChildCategoryPermissionsScreen
    extends StatefulWidget {
  const FamilyChildCategoryPermissionsScreen({
    super.key,
    required this.childProfile,
    required this.parentAccessToken,
  });

  final FamilyProfile childProfile;
  final String parentAccessToken;

  @override
  State<FamilyChildCategoryPermissionsScreen>
      createState() =>
          _FamilyChildCategoryPermissionsScreenState();
}

class _FamilyChildCategoryPermissionsScreenState
    extends State<FamilyChildCategoryPermissionsScreen> {
  final FamilyPinService _pinService =
      FamilyPinService();

  final FamilyProfileService _profileService =
      FamilyProfileService();

  final FamilyProfileManagementService
      _managementService =
      FamilyProfileManagementService();

  final FamilyPlaylistCategoryService
      _playlistCategories =
      FamilyPlaylistCategoryService();

  List<PlaylistProfile> _playlists = [];
  List<FamilyContentCategory> _categories = [];

  List<Map<String, dynamic>> _rules = [];

  String? _selectedSourceKey;

  FamilyContentType _selectedContentType =
      FamilyContentType.live;

  bool _loading = true;
  bool _saving = false;
  final Set<String> _selectedKeys = <String>{};
  String _search = '';

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _playlistCategories.dispose();
    super.dispose();
  }

  bool get _isChild =>
      widget.childProfile.type ==
      FamilyProfileType.child;

  Future<bool> _hasParentAuthorization() async {
    if (!_isChild) return false;

    try {
      return await _pinService.checkSession(
        scope: FamilyPinScope.parent,
        accessToken: widget.parentAccessToken,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    if (!_isChild) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Ordnerfreigaben sind nur für '
            'Kinderprofile verfügbar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authorized =
          await _hasParentAuthorization();

      if (!authorized) {
        throw const _FamilyPermissionError(
          'Die Eltern-PIN-Sitzung ist abgelaufen. '
          'Bitte die Verwaltung erneut entsperren.',
        );
      }

      final playlists =
          await _playlistCategories.loadPlaylists();

      final rules =
          await _profileService.loadCategoryRules(
        widget.childProfile.id,
      );

      if (!mounted) return;

      setState(() {
        _playlists = playlists;
        _rules = rules;
        _selectedSourceKey = playlists.isEmpty
            ? null
            : playlists.first.sourceKey;
        _loading = false;
      });

      await _loadSelectedCategories();
    } on _FamilyPermissionError catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            'Die Ordnerfreigaben konnten nicht '
            'geladen werden.';
      });
    }
  }

  Future<void> _loadSelectedCategories() async {
    final sourceKey = _selectedSourceKey;

    if (sourceKey == null) {
      if (!mounted) return;

      setState(() {
        _categories = [];
        _loading = false;
      });
      return;
    }

    final requestedType = _selectedContentType;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _categories = [];
    });

    try {
      final sourceType =
          await _playlistCategories.loadSourceType(
        sourceKey,
      );

      if (!mounted ||
          _selectedSourceKey != sourceKey ||
          _selectedContentType != requestedType) {
        return;
      }

      if (sourceType ==
          FamilyPlaylistSourceType.m3u) {
        setState(() {
          _loading = false;
          _errorMessage =
              'M3U-Ordner werden nach der '
              'Anbindung des bestehenden '
              'M3U-Parsers verfügbar. '
              'Bis dahin bleiben nicht '
              'freigegebene Kategorien gesperrt.';
        });
        return;
      }

      final categories =
          await _playlistCategories.loadXtreamCategories(
        sourceKey: sourceKey,
        contentType: requestedType,
      );

      if (!mounted ||
          _selectedSourceKey != sourceKey ||
          _selectedContentType != requestedType) {
        return;
      }

      setState(() {
        _categories = categories;
        _selectedKeys.clear();
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          _selectedSourceKey != sourceKey ||
          _selectedContentType != requestedType) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            'Die Kategorien konnten nicht '
            'geladen werden. Bitte die '
            'Playlistverbindung prüfen.';
      });
    }
  }

  bool _isCategoryVisible(
    FamilyContentCategory category,
  ) {
    return _profileService.isChildCategoryVisible(
      rules: _rules,
      sourceKey: category.sourceKey,
      contentType: category.contentTypeKey,
      categoryKey: category.categoryKey,
    );
  }

  Future<void> _changeVisibility(
    FamilyContentCategory category,
    bool visible,
  ) async {
    if (_saving || _loading) return;

    setState(() {
      _saving = true;
    });

    try {
      final authorized =
          await _hasParentAuthorization();

      if (!authorized) {
        throw const _FamilyPermissionError(
          'Die Eltern-PIN-Sitzung ist abgelaufen. '
          'Bitte erneut entsperren.',
        );
      }

      final success = await _managementService
          .setChildCategoryVisibility(
        parentAccessToken:
            widget.parentAccessToken,
        childProfileId:
            widget.childProfile.id,
        sourceKey: category.sourceKey,
        contentType: category.contentTypeKey,
        categoryKey: category.categoryKey,
        isVisible: visible,
      );

      if (!success) {
        throw const _FamilyPermissionError(
          'Die Freigabe wurde vom Server '
          'nicht bestätigt.',
        );
      }

      final updatedRules =
          await _profileService.loadCategoryRules(
        widget.childProfile.id,
      );

      if (!mounted) return;

      setState(() {
        _rules = updatedRules;
      });

      final confirmed =
          _isCategoryVisible(category) == visible;

      if (!confirmed) {
        _showMessage(
          'Die Freigabe konnte nicht '
          'bestätigt werden. Bitte aktualisieren.',
        );
      } else {
        _showMessage(
          visible
              ? 'Ordner freigegeben.'
              : 'Ordner gesperrt.',
        );
      }
    } on _FamilyPermissionError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        'Die Änderung konnte nicht '
        'gespeichert werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _selectPlaylist(
    String? sourceKey,
  ) async {
    if (sourceKey == null ||
        _saving ||
        _loading ||
        sourceKey == _selectedSourceKey) {
      return;
    }

    setState(() {
      _selectedSourceKey = sourceKey;
      _selectedKeys.clear();
      _search = '';
    });

    await _loadSelectedCategories();
  }

  Future<void> _selectContentType(
    FamilyContentType type,
  ) async {
    if (_saving ||
        _loading ||
        _selectedContentType == type) {
      return;
    }

    setState(() {
      _selectedContentType = type;
      _selectedKeys.clear();
      _search = '';
    });

    await _loadSelectedCategories();
  }

  Widget _buildPlaylistSelector() {
    if (_playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Es sind noch keine Playlists vorhanden.',
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedSourceKey),
      initialValue: _selectedSourceKey,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Playlist auswählen',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.playlist_play),
      ),
      items: _playlists.map((playlist) {
        return DropdownMenuItem<String>(
          value: playlist.sourceKey,
          child: Text(
            playlist.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _saving || _loading
          ? null
          : _selectPlaylist,
    );
  }

  Widget _buildContentTypeSelector() {
    return SegmentedButton<FamilyContentType>(
      segments: const [
        ButtonSegment(
          value: FamilyContentType.live,
          icon: Icon(Icons.live_tv),
          label: Text('Live-TV'),
        ),
        ButtonSegment(
          value: FamilyContentType.vod,
          icon: Icon(Icons.movie_outlined),
          label: Text('Filme'),
        ),
        ButtonSegment(
          value: FamilyContentType.series,
          icon: Icon(Icons.tv_outlined),
          label: Text('Serien'),
        ),
      ],
      selected: {_selectedContentType},
      onSelectionChanged: _saving || _loading
          ? null
          : (selection) {
              if (selection.isNotEmpty) {
                _selectContentType(
                  selection.first,
                );
              }
            },
    );
  }

  Future<void> _applyBulk(bool visible) async {
    if (_saving || _loading || _selectedKeys.isEmpty) return;
    setState(() => _saving = true);
    var updated = 0;
    try {
      if (!await _hasParentAuthorization()) {
        throw const _FamilyPermissionError(
          'Eltern-PIN-Sitzung abgelaufen. Bitte Verwaltung erneut entsperren.',
        );
      }
      final chosen = _categories
          .where((c) => _selectedKeys.contains(c.categoryKey))
          .toList(growable: false);
      for (final category in chosen) {
        final ok = await _managementService.setChildCategoryVisibility(
          parentAccessToken: widget.parentAccessToken,
          childProfileId: widget.childProfile.id,
          sourceKey: category.sourceKey,
          contentType: category.contentTypeKey,
          categoryKey: category.categoryKey,
          isVisible: visible,
        );
        if (!ok) throw const _FamilyPermissionError(
          'Der Server hat eine Änderung nicht bestätigt.',
        );
        updated++;
      }
      final rules = await _profileService.loadCategoryRules(widget.childProfile.id);
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _selectedKeys.clear();
      });
      _showMessage('$updated Ordner ${visible ? 'entsperrt' : 'gesperrt'}.');
    } catch (error) {
      // Einzelne bereits bestätigte Änderungen bleiben gespeichert.
      try {
        final rules = await _profileService.loadCategoryRules(widget.childProfile.id);
        if (mounted) setState(() => _rules = rules);
      } catch (_) {}
      _showMessage('Änderung unterbrochen ($updated erfolgreich). Bitte erneut prüfen.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCategoryList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_errorMessage!, textAlign: TextAlign.center),
          OutlinedButton.icon(
            onPressed: _loadSelectedCategories,
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut versuchen'),
          ),
        ]),
      ));
    }
    final filtered = _categories.where((c) =>
        c.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
    if (filtered.isEmpty) return const Center(child: Text('Keine Ordner gefunden.'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final category = filtered[index];
        final selected = _selectedKeys.contains(category.categoryKey);
        final visible = _isCategoryVisible(category);
        return CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: selected,
          onChanged: _saving ? null : (value) => setState(() {
            if (value == true) {
              _selectedKeys.add(category.categoryKey);
            } else {
              _selectedKeys.remove(category.categoryKey);
            }
          }),
          title: Text(category.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(visible ? 'Sichtbar' : 'Gesperrt'),
          secondary: Icon(visible ? Icons.lock_open_outlined : Icons.lock_outline),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Kinderprofil: ${widget.childProfile.displayName}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Alle Ordner sind zunächst sichtbar. Markierte Ordner können gesperrt werden.'),
        const SizedBox(height: 12),
        _buildPlaylistSelector(),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildContentTypeSelector(),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Ordner suchen',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
      ]),
    );
  }

  Widget _buildActions() {
    final filtered = _categories.where((c) =>
        c.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${_selectedKeys.length} ausgewählt'),
          OutlinedButton(
            onPressed: _saving || _loading ? null : () => setState(() {
              _selectedKeys.addAll(filtered.map((c) => c.categoryKey));
            }),
            child: const Text('Alle auswählen'),
          ),
          OutlinedButton(
            onPressed: _saving || _loading ? null : () => setState(_selectedKeys.clear),
            child: const Text('Auswahl löschen'),
          ),
          FilledButton.icon(
            onPressed: _saving || _selectedKeys.isEmpty ? null : () => _applyBulk(false),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Sperren'),
          ),
          OutlinedButton.icon(
            onPressed: _saving || _selectedKeys.isEmpty ? null : () => _applyBulk(true),
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Entsperren'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinder-Ordnersperren'),
        actions: [IconButton(
          tooltip: 'Aktualisieren',
          onPressed: _loading || _saving ? null : _initialize,
          icon: const Icon(Icons.refresh),
        )],
      ),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final controls = SingleChildScrollView(child: _buildControls());
        final list = Column(children: [
          if (_saving) const LinearProgressIndicator(),
          _buildActions(),
          Expanded(child: _buildCategoryList()),
        ]);
        if (wide) {
          return Row(children: [
            SizedBox(width: constraints.maxWidth * 0.38, child: controls),
            const VerticalDivider(width: 1),
            Expanded(child: list),
          ]);
        }
        return Column(children: [
          SizedBox(height: constraints.maxHeight * 0.43, child: controls),
          Expanded(child: list),
        ]);
      })),
    );
  }

}

class _FamilyPermissionError
    implements Exception {
  final String message;

  const _FamilyPermissionError(this.message);
}

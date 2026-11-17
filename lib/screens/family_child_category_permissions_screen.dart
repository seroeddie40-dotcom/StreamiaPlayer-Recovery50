import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';

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
  String _t(String key) => AppLocalizations.of(context).t(key);
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
        _errorMessage = 'family_child_only';
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
          'family_session_expired',
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
        _errorMessage = 'family_rules_load';
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
          _errorMessage = 'family_m3u_notice';
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
        _errorMessage = 'family_categories_load';
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
          'family_session_expired',
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
          'folder_server_unconfirmed',
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

      final confirmed = _profileService.isChildCategoryVisible(
        rules: updatedRules,
        sourceKey: category.sourceKey,
        contentType: category.contentTypeKey,
        categoryKey: category.categoryKey,
      ) == visible;

      if (!confirmed) {
        _showMessage(
          'folder_verify_failed',
        );
      } else {
        _showMessage(
          visible
              ? 'folder_allowed'
              : 'folder_denied',
        );
      }
    } on _FamilyPermissionError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        'folder_save_failed',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message, {int? count}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(message).replaceAll('{count}', count?.toString() ?? '')),
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
      decoration: InputDecoration(
        labelText: _t('family_choose_playlist'),
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
    return DropdownButtonFormField<FamilyContentType>(
      initialValue: _selectedContentType,
      isExpanded: true,
      decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
      items: [
        DropdownMenuItem(value: FamilyContentType.live, child: Text(_t('nav_live'))),
        DropdownMenuItem(value: FamilyContentType.vod, child: Text(_t('nav_vod'))),
        DropdownMenuItem(value: FamilyContentType.series, child: Text(_t('nav_series'))),
      ],
      onChanged: _saving || _loading ? null : (value) {
        if (value != null) _selectContentType(value);
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
          'family_session_expired',
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
          'folder_server_unconfirmed',
        );
        updated++;
      }
      final rules = await _profileService.loadCategoryRules(widget.childProfile.id);
      final confirmed = chosen.every((category) =>
          _profileService.isChildCategoryVisible(
            rules: rules,
            sourceKey: category.sourceKey,
            contentType: category.contentTypeKey,
            categoryKey: category.categoryKey,
          ) == visible);
      if (!confirmed) {
        throw const _FamilyPermissionError(
          'folder_rules_mismatch',
        );
      }
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _selectedKeys.clear();
      });
      _showMessage(visible ? 'folder_bulk_allowed' : 'folder_bulk_denied', count: updated);
    } catch (error) {
      // Einzelne bereits bestätigte Änderungen bleiben gespeichert.
      try {
        final rules = await _profileService.loadCategoryRules(widget.childProfile.id);
        if (mounted) setState(() => _rules = rules);
      } catch (_) {}
      _showMessage('folder_bulk_interrupted', count: updated);
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
          Text(_t(_errorMessage!), textAlign: TextAlign.center),
          OutlinedButton.icon(
            onPressed: _loadSelectedCategories,
            icon: const Icon(Icons.refresh),
            label: Text(_t('family_retry')),
          ),
        ]),
      ));
    }
    final filtered = _categories.where((c) =>
        c.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
    if (filtered.isEmpty) return Center(child: Text(_t('family_no_folders')));
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
          subtitle: Text(visible ? _t('family_visible') : _t('family_blocked')),
          secondary: IconButton(
            tooltip: visible ? _t('family_lock_folder') : _t('family_unlock_folder'),
            onPressed: _saving || _loading
                ? null
                : () => _changeVisibility(category, !visible),
            icon: Icon(
              visible ? Icons.lock_open_outlined : Icons.lock_outline,
              color: visible ? null : Theme.of(context).colorScheme.error,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${_t('family_child')}: ${widget.childProfile.displayName}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(_t('family_lock_hint')),
        const SizedBox(height: 12),
        _buildPlaylistSelector(),
        const SizedBox(height: 12),
        _buildContentTypeSelector(),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: _t('family_search_folder'),
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
          Text('${_selectedKeys.length} ${_t('family_selected')} · ${_categories.where((c) => !_isCategoryVisible(c)).length} ${_t('family_blocked_count')}'),
          OutlinedButton(
            onPressed: _saving || _loading ? null : () => setState(() {
              _selectedKeys.addAll(filtered.map((c) => c.categoryKey));
            }),
            child: Text(_t('family_select_all')),
          ),
          OutlinedButton(
            onPressed: _saving || _loading ? null : () => setState(_selectedKeys.clear),
            child: Text(_t('family_clear_selection')),
          ),
          FilledButton.icon(
            onPressed: _saving || _selectedKeys.isEmpty ? null : () => _applyBulk(false),
            icon: const Icon(Icons.lock_outline),
            label: Text(_t('family_lock')),
          ),
          OutlinedButton.icon(
            onPressed: _saving || _selectedKeys.isEmpty ? null : () => _applyBulk(true),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(_t('family_unlock')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('family_folder_rules')),
        actions: [IconButton(
          tooltip: _t('playlist_refresh'),
          onPressed: _loading || _saving ? null : _initialize,
          icon: const Icon(Icons.refresh),
        )],
      ),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final controls = SingleChildScrollView(child: _buildControls());
        final list = Column(children: [
          if (_saving) const LinearProgressIndicator(),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * (wide ? 0.30 : 0.19)),
            child: SingleChildScrollView(child: _buildActions()),
          ),
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

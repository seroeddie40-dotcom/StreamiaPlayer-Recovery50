
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

  Widget _buildCategoryList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : _loadSelectedCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Für diesen Bereich wurden '
            'keine Kategorien gefunden.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];

        final visible =
            _isCategoryVisible(category);

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: SwitchListTile(
            title: Text(
              category.displayName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              visible
                  ? 'Für dieses Kind freigegeben'
                  : 'Für dieses Kind gesperrt',
            ),
            secondary: Icon(
              visible
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline,
            ),
            value: visible,
            onChanged: _saving
                ? null
                : (value) {
                    _changeVisibility(
                      category,
                      value,
                    );
                  },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinder-Ordnerfreigaben'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _loading || _saving
                ? null
                : _initialize,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_saving)
              const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Kinderprofil: '
                    '${widget.childProfile.displayName}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nur ausdrücklich freigegebene '
                    'Ordner sollen für dieses '
                    'Kinderprofil sichtbar sein.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _buildPlaylistSelector(),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildContentTypeSelector(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildCategoryList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyPermissionError
    implements Exception {
  final String message;

  const _FamilyPermissionError(this.message);
}

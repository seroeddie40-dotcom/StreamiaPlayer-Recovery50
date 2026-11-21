import '../widgets/tv_catalog_focus.dart';
import '../widgets/tv_pin_keypad.dart';
import '../core/platform/device_layout.dart';

import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/family_session_provider.dart';
import 'package:flutter/services.dart';

import '../models/family_profile.dart';
import '../services/family_profile_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_management_service.dart';
import 'family_child_category_permissions_screen.dart';
import 'family_parent_pin_setup_screen.dart';
import 'downloads_screen.dart';
import 'recordings_screen.dart';

class FamilyProfileManagementScreen extends StatefulWidget {
  const FamilyProfileManagementScreen({super.key, this.rulesOnly = false, this.useActiveSession = false});

  final bool rulesOnly;
  final bool useActiveSession;

  @override
  State<FamilyProfileManagementScreen> createState() =>
      _FamilyProfileManagementScreenState();
}

class _FamilyProfileManagementScreenState
    extends State<FamilyProfileManagementScreen> {
  String _t(String key) => AppLocalizations.of(context).t(key);
  final FamilyProfileService _profileService =
      FamilyProfileService();

  final FamilyPinService _pinService = FamilyPinService();

  final FamilyProfileManagementService _managementService =
      FamilyProfileManagementService();

  List<FamilyProfile> _profiles = [];

  bool _loading = true;
  bool _accessGranted = false;
  bool _unlocking = false;
  bool _busy = false;

  String? _error;
  String? _parentToken;
  DateTime? _parentTokenExpiry;

  int _profileLimit = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _unlockManagement();
      }
    });
  }

  @override
  void dispose() {
    _parentToken = null;
    _parentTokenExpiry = null;
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _ensureParentPinConfigured() async {
    final status = await _pinService.getParentPinStatus();

    if (!mounted) return false;

    switch (status) {
      case FamilyParentPinStatus.configured:
        return true;

      case FamilyParentPinStatus.notConfigured:
        final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const FamilyParentPinSetupScreen(),
          ),
        );

        if (!mounted || created != true) return false;

        final updatedStatus =
            await _pinService.getParentPinStatus();

        if (!mounted) return false;

        if (updatedStatus ==
            FamilyParentPinStatus.configured) {
          _showMessage(
            _t('family_setup_pin_saved'),
          );
          return true;
        }

        _showMessage(
          _t('family_setup_pin_failed'),
        );
        return false;

      case FamilyParentPinStatus.unauthorized:
        _showMessage(
          _t('family_setup_pin_login'),
        );
        return false;

      case FamilyParentPinStatus.unknown:
        _showMessage(
          _t('family_server_verify_failed'),
        );
        return false;
    }
  }

  Future<void> _unlockManagement() async {
    if (context.read<FamilySessionProvider>().isChild) return;
    if (_unlocking || _busy || !mounted) return;

    setState(() {
      _unlocking = true;
      _error = null;
    });

    try {
      if (!widget.useActiveSession) {
        final configured = await _ensureParentPinConfigured();
        if (!configured || !mounted) return;
      }

      final token = await _requireParentToken();

      if (token == null || !mounted) return;

      setState(() {
        _accessGranted = true;
      });

      await _loadData();
    } catch (_) {
      _showMessage(
        _t('family_pin_verify_failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _unlocking = false;
          _loading = false;
        });
      }
    }
  }

  Future<String?> _requireParentToken() async {
    if (!mounted) return null;

    if (widget.useActiveSession) {
      final family = context.read<FamilySessionProvider>();
      final token = family.parentAccessToken;
      if (token == null) return null;
      try {
        final valid = await _pinService.checkSession(scope: FamilyPinScope.parent, accessToken: token);
        if (!mounted || !valid || family.parentAccessToken != token) return null;
        return token;
      } catch (_) {
        return null;
      }
    }
    final existingToken = _parentToken;
    final expiry = _parentTokenExpiry;

    if (existingToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now())) {
      try {
        final valid = await _pinService.checkSession(
          scope: FamilyPinScope.parent,
          accessToken: existingToken,
        );

        if (valid) return existingToken;
      } catch (_) {
        // A new server verification is required.
      }
    }

    _parentToken = null;
    _parentTokenExpiry = null;

    if (!mounted) return null;

    final controller = TextEditingController();
    bool checking = false;
    bool showPin = false;
    String? errorMessage;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, updateDialog) {
              Future<void> submit() async {
                if (checking) return;

                final pin = controller.text;

                // Existing longer PINs remain accepted here
                // to avoid locking out existing accounts.
                // Newly created PINs use 6–10 digits.
                if (!RegExp(r'^[0-9]{6,12}$').hasMatch(pin)) {
                  updateDialog(() {
                    errorMessage =
                        _t('family_pin_valid');
                  });
                  return;
                }

                updateDialog(() {
                  checking = true;
                  errorMessage = null;
                });

                try {
                  final verification =
                      await _pinService.verifyPin(
                    scope: FamilyPinScope.parent,
                    pin: pin,
                  );

                  if (!dialogContext.mounted) return;

                  if (verification.isSuccessful) {
                    _parentToken = verification.accessToken;
                    _parentTokenExpiry =
                        verification.validUntil;

                    Navigator.of(dialogContext).pop(
                      verification.accessToken,
                    );
                    return;
                  }

                  updateDialog(() {
                    switch (verification.status) {
                      case 'not_configured':
                        errorMessage =
                            _t('family_pin_not_configured');
                        break;
                      case 'locked':
                        errorMessage =
                            _t('family_pin_locked');
                        break;
                      case 'invalid_pin':
                        errorMessage =
                            _t('family_pin_wrong');
                        break;
                      case 'unauthorized':
                        errorMessage =
                            _t('family_pin_expired');
                        break;
                      default:
                        errorMessage =
                            _t('family_pin_verify_failed');
                    }
                  });
                } catch (_) {
                  if (!dialogContext.mounted) return;

                  updateDialog(() {
                    errorMessage =
                        _t('family_server_verify_failed');
                  });
                } finally {
                  if (dialogContext.mounted) {
                    updateDialog(() {
                      checking = false;
                    });
                  }
                }
              }

              if (DeviceLayout.isTelevision) {
                return Dialog(
                  insetPadding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 940),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(_t('family_pin_required'),
                                    style: Theme.of(dialogContext).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                Text(_t('family_management_protected')),
                                const SizedBox(height: 18),
                                InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: _t('family_parent_pin'),
                                  ),
                                  child: Text(showPin
                                      ? controller.text
                                      : '●' * controller.text.length),
                                ),
                                CheckboxListTile(
                                  value: showPin,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_t('family_show_pin')),
                                  onChanged: checking ? null : (value) =>
                                      updateDialog(() => showPin = value ?? false),
                                ),
                                if (errorMessage != null)
                                  Text(errorMessage!,
                                      style: TextStyle(
                                          color: Theme.of(dialogContext)
                                              .colorScheme.error)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: checking ? null : () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: Text(_t('playlist_cancel')),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: checking
                                ? const Center(child: CircularProgressIndicator())
                                : TvPinKeypad(
                                    autofocus: true,
                                    value: controller.text,
                                    maxLength: 12,
                                    onChanged: (value) => updateDialog(() {
                                      controller.text = value;
                                      errorMessage = null;
                                    }),
                                    onSubmit: submit,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _t('family_pin_required'),
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _t('family_management_protected'),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            obscureText: !showPin,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: _t('family_parent_pin'),
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => submit(),
                          ),
                          CheckboxListTile(
                            value: showPin,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_t('family_show_pin')),
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            onChanged: checking
                                ? null
                                : (value) {
                                    updateDialog(() {
                                      showPin = value ?? false;
                                    });
                                  },
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              TextButton(
                                autofocus: true,
                                onPressed: checking
                                    ? null
                                    : () => Navigator.of(dialogContext)
                                        .pop(),
                                child: Text(_t('playlist_cancel')),
                              ),
                              FilledButton(
                                onPressed: checking ? null : submit,
                                child: checking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_t('family_confirm')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted || !_accessGranted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _requireParentToken();

      if (token == null || !mounted) {
        if (mounted) {
          setState(() {
            _accessGranted = false;
            _loading = false;
          });
        }
        return;
      }

      final profiles = await _profileService.loadProfiles();
      final limit =
          await _managementService.loadProfileLimit();

      if (!mounted) return;
      if (widget.useActiveSession && context.read<FamilySessionProvider>().parentAccessToken != token) return;

      setState(() {
        _profiles = profiles;
        _profileLimit = limit;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            _t('family_profiles_load_failed');
      });
    }
  }

  Future<void> _createProfile() async {
    if (_busy ||
        !_accessGranted ||
        _profileLimit <= 0 ||
        _profiles.length >= _profileLimit) {
      return;
    }

    final token = await _requireParentToken();
    if (token == null || !mounted) return;

    final firstProfile = _profiles.isEmpty;
    final nameController = TextEditingController();

    String type = firstProfile ? 'adult' : 'child';

    try {
      final input = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, updateDialog) {
              return AlertDialog(
                title: Text(
                  firstProfile
                      ? _t('family_first_adult')
                      : _t('family_add'),
                ),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (firstProfile) ...[
                          Text(_t('family_first_adult_hint'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          maxLength: 60,
                          decoration: InputDecoration(
                            labelText: _t('family_name'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (firstProfile)
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t('family_type'),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_t('family_adult')),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: InputDecoration(
                              labelText: _t('family_type'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'adult',
                                child: Text(_t('family_adult')),
                              ),
                              DropdownMenuItem(
                                value: 'child',
                                child: Text(_t('family_child')),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                updateDialog(() {
                                  type = value;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(),
                    child: Text(_t('playlist_cancel')),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      Navigator.of(dialogContext).pop({
                        'name': name,
                        'type': firstProfile ? 'adult' : type,
                      });
                    },
                    child: Text(_t('family_create')),
                  ),
                ],
              );
            },
          );
        },
      );

      if (input == null || !mounted) return;
      if (await _requireParentToken() != token || !mounted) return;

      setState(() => _busy = true);

      await _managementService.createProfile(
        parentAccessToken: token,
        displayName: input['name']!,
        profileType: input['type']!,
      );

      if (!mounted) return;

      setState(() => _busy = false);

      await _loadData();

      if (!mounted) return;

      // No additional adult PIN setup is required.
      // Every adult profile uses the shared parent PIN.
      _showMessage(
        input['type'] == 'adult'
            ? _t('family_adult_created')
            : _t('family_child_created'),
      );
    } catch (_) {
      _showMessage(
        _t('family_create_failed'),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });

      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _renameProfile(
    FamilyProfile profile,
  ) async {
    if (_busy || !_accessGranted) return;

    final token = await _requireParentToken();
    if (token == null || !mounted) return;

    final controller = TextEditingController(
      text: profile.displayName,
    );

    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(_t('family_rename')),
            content: SingleChildScrollView(
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: _t('family_name'),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: Text(_t('playlist_cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();

                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: Text(_t('playlist_save')),
              ),
            ],
          );
        },
      );

      if (newName == null || !mounted) return;
      if (await _requireParentToken() != token || !mounted) return;

      setState(() => _busy = true);

      final success =
          await _managementService.updateProfile(
        parentAccessToken: token,
        profileId: profile.id,
        displayName: newName,
        avatarKey: profile.avatarKey,
      );

      if (!mounted) return;

      if (success) {
        _showMessage(_t('family_feedback_updated'));
        await _loadData();
      } else {
        _showMessage(_t('family_feedback_missing'));
      }
    } catch (_) {
      _showMessage(
        _t('family_feedback_update_failed'),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });

      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setDefault(
    FamilyProfile profile,
  ) async {
    if (_busy ||
        !_accessGranted ||
        profile.isDefault ||
        profile.type != FamilyProfileType.adult) {
      return;
    }

    final token = await _requireParentToken();
    if (token == null || !mounted) return;

    setState(() => _busy = true);

    try {
      final success =
          await _managementService.setDefaultProfile(
        parentAccessToken: token,
        profileId: profile.id,
      );

      if (!mounted) return;

      if (success) {
        _showMessage(_t('family_feedback_default_changed'));
        await _loadData();
      } else {
        _showMessage(
          _t('family_feedback_default_adult'),
        );
      }
    } catch (_) {
      _showMessage(
        _t('family_feedback_default_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProfile(
    FamilyProfile profile,
  ) async {
    if (_busy ||
        !_accessGranted ||
        profile.isDefault) {
      return;
    }

    final token = await _requireParentToken();
    if (token == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('family_delete_question')),
          content: SingleChildScrollView(
            child: Text(
              _t('family_delete_details').replaceAll('{name}', profile.displayName),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: Text(_t('playlist_cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: Text(_t('family_delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    if (await _requireParentToken() != token || !mounted) return;

    setState(() => _busy = true);

    try {
      final success =
          await _managementService.deleteProfile(
        parentAccessToken: token,
        profileId: profile.id,
      );

      if (!mounted) return;

      if (success) {
        _showMessage(_t('family_feedback_deleted'));
        await _loadData();
      } else {
        _showMessage(_t('family_feedback_missing'));
      }
    } catch (_) {
      _showMessage(
        _t('family_feedback_delete_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openChildPermissions(
    FamilyProfile profile,
  ) async {
    if (_busy ||
        !_accessGranted ||
        (profile.isAdult && context.read<FamilySessionProvider>().activeProfile?.id != profile.id)) {
      return;
    }

    final token = await _requireParentToken();
    if (token == null || !mounted) return;

    try {
      final valid = await _pinService.checkSession(
        scope: FamilyPinScope.parent,
        accessToken: token,
      );

      if (!mounted) return;

      if (!valid) {
        _parentToken = null;
        _parentTokenExpiry = null;

        _showMessage(
          _t('family_session_expired'),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              FamilyChildCategoryPermissionsScreen(
            childProfile: profile,
            parentAccessToken: token,
            requireActiveSession: widget.useActiveSession,
          ),
        ),
      );

      if (mounted) {
        await _loadData();
      }
    } catch (_) {
      _showMessage(
        _t('family_feedback_rules_failed'),
      );
    }
  }

  Future<void> _manageChildMedia(FamilyProfile profile, {required bool downloads}) async {
    if (_busy || !_accessGranted || !profile.isChild) return;
    final family = context.read<FamilySessionProvider>();
    final token = await _requireParentToken();
    if (!mounted || token == null || family.parentAccessToken != token || family.activeProfile?.accountUserId != profile.accountUserId) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => downloads ? DownloadsScreen(managedChild: profile) : RecordingsScreen(managedChild: profile)));
  }

  Widget _buildProfileTile(FamilyProfile profile) {
    final isAdult =
        profile.type == FamilyProfileType.adult;

    return TvCatalogFocus(child: Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isAdult
                ? Icons.person
                : Icons.child_care,
          ),
        ),
        onTap: widget.rulesOnly ? () => _openChildPermissions(profile) : null,
        title: Text(profile.displayName),
        subtitle: Text(
          '${_t(isAdult ? 'family_adult' : 'family_child')}'
          '${widget.rulesOnly ? " · ${_t(isAdult ? 'adult_folder_hide' : 'family_lock_folder')}" : ""}'
          '${profile.isDefault ? " · ${_t('family_default')}" : ""}',
        ),
        trailing: widget.rulesOnly ? const Icon(Icons.chevron_right) : PopupMenuButton<String>(
          enabled: !_busy,
          tooltip: _t('family_manage_one'),
          onSelected: (action) {
            switch (action) {
              case 'permissions':
                _openChildPermissions(profile);
                break;
              case 'child_downloads':
                _manageChildMedia(profile, downloads: true);
                break;
              case 'child_recordings':
                _manageChildMedia(profile, downloads: false);
                break;
              case 'rename':
                _renameProfile(profile);
                break;
              case 'default':
                _setDefault(profile);
                break;
              case 'delete':
                _deleteProfile(profile);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!isAdult)
              PopupMenuItem(
                value: 'permissions',
                child: Text(_t('family_manage_rules')),
              ),
            if (!isAdult && widget.useActiveSession) ...[
              PopupMenuItem(value: 'child_downloads', child: Text(_t('family_child_downloads'))),
              PopupMenuItem(value: 'child_recordings', child: Text(_t('family_child_recordings'))),
            ],
            PopupMenuItem(
              value: 'rename',
              child: Text(_t('family_rename')),
            ),
            if (isAdult && !profile.isDefault)
              PopupMenuItem(
                value: 'default',
                child: Text(_t('family_set_default')),
              ),
            if (!profile.isDefault)
              PopupMenuItem(
                value: 'delete',
                child: Text(_t('family_delete')),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _buildLockedContent() {
    if (_unlocking) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(_t('family_management_protected'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(_t('family_management_unlock_hint'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _unlockManagement,
              icon: const Icon(Icons.lock_open),
              label: Text(_t('family_management_unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadData,
                child: Text(_t('family_retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.rulesOnly) {
      final active = context.watch<FamilySessionProvider>().activeProfile;
      final children = _profiles.where((p) => p.isChild || (p.isAdult && p.id == active?.id)).toList();
      return children.isEmpty ? Center(child: Text(_t('family_no_child_profiles'))) : ListView.builder(itemCount: children.length, itemBuilder: (_, i) => _buildProfileTile(children[i]));
    }
    return Column(
      children: [
        if (_busy)
          const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              Text(
                "${_t('family_profile_count')}: ${_profiles.length} / $_profileLimit",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              FilledButton.icon(
                onPressed: _busy ||
                        _profileLimit <= 0 ||
                        _profiles.length >= _profileLimit
                    ? null
                    : _createProfile,
                icon: const Icon(Icons.add),
                label: Text(
                  _profiles.isEmpty
                      ? _t('family_first_profile')
                      : _t('family_add'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _profiles.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.family_restroom,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(_t('family_no_profiles'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(_t('family_create_adult_first'),
                          textAlign: TextAlign.center,
                        ),
                        if (_profileLimit <= 0) ...[
                          const SizedBox(height: 12),
                          Text(_t('family_no_slots'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    return _buildProfileTile(
                      _profiles[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChild = context.watch<FamilySessionProvider>().isChild;
    if (isChild || (widget.useActiveSession && context.watch<FamilySessionProvider>().parentAccessToken == null)) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('family_manage'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_t('family_adult_only')),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(widget.rulesOnly ? 'family_manage_rules' : 'family_manage')),
        actions: [
          IconButton(
            tooltip: _t('playlist_refresh'),
            onPressed: _busy || _unlocking
                ? null
                : _accessGranted
                    ? _loadData
                    : _unlockManagement,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _accessGranted
            ? _buildManagementContent()
            : _buildLockedContent(),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/family_profile.dart';
import '../services/family_profile_service.dart';
import '../services/family_pin_service.dart';
import '../services/family_profile_management_service.dart';
import 'family_child_category_permissions_screen.dart';
import 'family_parent_pin_setup_screen.dart';

class FamilyProfileManagementScreen extends StatefulWidget {
  const FamilyProfileManagementScreen({super.key});

  @override
  State<FamilyProfileManagementScreen> createState() =>
      _FamilyProfileManagementScreenState();
}

class _FamilyProfileManagementScreenState
    extends State<FamilyProfileManagementScreen> {
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
            'Eltern-PIN eingerichtet. '
            'Bitte zur Bestätigung eingeben.',
          );
          return true;
        }

        _showMessage(
          'Die Einrichtung konnte nicht bestätigt werden.',
        );
        return false;

      case FamilyParentPinStatus.unauthorized:
        _showMessage(
          'Bitte zuerst mit deinem Konto anmelden.',
        );
        return false;

      case FamilyParentPinStatus.unknown:
        _showMessage(
          'Der Eltern-PIN-Status konnte nicht erkannt werden.',
        );
        return false;
    }
  }

  Future<void> _unlockManagement() async {
    if (_unlocking || _busy || !mounted) return;

    setState(() {
      _unlocking = true;
      _error = null;
    });

    try {
      final configured = await _ensureParentPinConfigured();

      if (!configured || !mounted) return;

      final token = await _requireParentToken();

      if (token == null || !mounted) return;

      setState(() {
        _accessGranted = true;
      });

      await _loadData();
    } catch (_) {
      _showMessage(
        'Die Familienverwaltung konnte '
        'nicht entsperrt werden.',
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
                        'Bitte eine gültige Eltern-PIN eingeben.';
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
                            'Die Eltern-PIN ist noch nicht eingerichtet.';
                        break;
                      case 'locked':
                        errorMessage =
                            'Zu viele Fehlversuche. Bitte später erneut versuchen.';
                        break;
                      case 'invalid_pin':
                        errorMessage =
                            'Die Eltern-PIN ist falsch.';
                        break;
                      case 'unauthorized':
                        errorMessage =
                            'Die Anmeldung ist abgelaufen.';
                        break;
                      default:
                        errorMessage =
                            'PIN-Prüfung fehlgeschlagen.';
                    }
                  });
                } catch (_) {
                  if (!dialogContext.mounted) return;

                  updateDialog(() {
                    errorMessage =
                        'Serverprüfung fehlgeschlagen.';
                  });
                } finally {
                  if (dialogContext.mounted) {
                    updateDialog(() {
                      checking = false;
                    });
                  }
                }
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
                            'Eltern-PIN erforderlich',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Die Familienverwaltung ist '
                            'mit deiner gemeinsamen Eltern-PIN geschützt.',
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
                            decoration: const InputDecoration(
                              labelText: 'Eltern-PIN',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => submit(),
                          ),
                          CheckboxListTile(
                            value: showPin,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('PIN anzeigen'),
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
                                child: const Text('Abbrechen'),
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
                                    : const Text('Bestätigen'),
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
            'Die Familienprofile konnten nicht geladen werden.';
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
                      ? 'Erstes Erwachsenenprofil'
                      : 'Profil hinzufügen',
                ),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (firstProfile) ...[
                          const Text(
                            'Das erste Familienprofil muss '
                            'ein Erwachsenenprofil sein. '
                            'Danach können weitere Erwachsenen- '
                            'und Kinderprofile hinzugefügt werden.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            labelText: 'Profilname',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (firstProfile)
                          const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Profiltyp',
                              border: OutlineInputBorder(),
                            ),
                            child: Text('Erwachsenenprofil'),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(
                              labelText: 'Profiltyp',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'adult',
                                child: Text('Erwachsenenprofil'),
                              ),
                              DropdownMenuItem(
                                value: 'child',
                                child: Text('Kinderprofil'),
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
                    child: const Text('Abbrechen'),
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
                    child: const Text('Erstellen'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (input == null || !mounted) return;

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
            ? 'Erwachsenenprofil erstellt. '
                'Es verwendet die gemeinsame Eltern-PIN.'
            : 'Kinderprofil erstellt. '
                'Du kannst jetzt die Ordnersperren festlegen.',
      );
    } catch (_) {
      _showMessage(
        'Das Profil konnte nicht erstellt werden.',
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
            title: const Text('Profil umbenennen'),
            content: SingleChildScrollView(
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Profilname',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();

                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      );

      if (newName == null || !mounted) return;

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
        _showMessage('Profil aktualisiert.');
        await _loadData();
      } else {
        _showMessage('Profil nicht gefunden.');
      }
    } catch (_) {
      _showMessage(
        'Das Profil konnte nicht geändert werden.',
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
        _showMessage('Standardprofil geändert.');
        await _loadData();
      } else {
        _showMessage(
          'Nur Erwachsenenprofile sind zulässig.',
        );
      }
    } catch (_) {
      _showMessage(
        'Standardprofil konnte nicht geändert werden.',
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
          title: const Text('Profil löschen?'),
          content: SingleChildScrollView(
            child: Text(
              'Möchtest du "${profile.displayName}" '
              'wirklich löschen? '
              'Die zugehörigen Profildaten und '
              'Ordnerfreigaben werden entfernt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final success =
          await _managementService.deleteProfile(
        parentAccessToken: token,
        profileId: profile.id,
      );

      if (!mounted) return;

      if (success) {
        _showMessage('Profil gelöscht.');
        await _loadData();
      } else {
        _showMessage('Profil nicht gefunden.');
      }
    } catch (_) {
      _showMessage(
        'Profil konnte nicht gelöscht werden. '
        'Standardprofile und das letzte '
        'Erwachsenenprofil sind geschützt.',
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
        profile.type != FamilyProfileType.child) {
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
          'Eltern-PIN-Sitzung abgelaufen.',
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              FamilyChildCategoryPermissionsScreen(
            childProfile: profile,
            parentAccessToken: token,
          ),
        ),
      );

      if (mounted) {
        await _loadData();
      }
    } catch (_) {
      _showMessage(
        'Die Ordnersperren konnten nicht geöffnet werden.',
      );
    }
  }

  Widget _buildProfileTile(FamilyProfile profile) {
    final isAdult =
        profile.type == FamilyProfileType.adult;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isAdult
                ? Icons.person
                : Icons.child_care,
          ),
        ),
        title: Text(profile.displayName),
        subtitle: Text(
          '${isAdult ? "Erwachsenenprofil" : "Kinderprofil"}'
          '${profile.isDefault ? " · Standard" : ""}',
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_busy,
          tooltip: 'Profil verwalten',
          onSelected: (action) {
            switch (action) {
              case 'permissions':
                _openChildPermissions(profile);
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
              const PopupMenuItem(
                value: 'permissions',
                child: Text('Ordnersperren verwalten'),
              ),
            const PopupMenuItem(
              value: 'rename',
              child: Text('Umbenennen'),
            ),
            if (isAdult && !profile.isDefault)
              const PopupMenuItem(
                value: 'default',
                child: Text('Als Standard festlegen'),
              ),
            if (!profile.isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Löschen'),
              ),
          ],
        ),
      ),
    );
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
            const Text(
              'Familienverwaltung geschützt',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Richte deine Eltern-PIN ein oder '
              'entsperre die Verwaltung mit '
              'deiner bestehenden PIN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _unlockManagement,
              icon: const Icon(Icons.lock_open),
              label: const Text(
                'Familienverwaltung entsperren',
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
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
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
                'Profile: ${_profiles.length} / $_profileLimit',
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
                      ? 'Erstes Profil erstellen'
                      : 'Profil hinzufügen',
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
                        const Text(
                          'Noch keine Familienprofile vorhanden.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Erstelle zuerst ein Erwachsenenprofil.',
                          textAlign: TextAlign.center,
                        ),
                        if (_profileLimit <= 0) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Der Server hat derzeit '
                            'keinen verfügbaren '
                            'Profilplatz gemeldet.',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familienprofile verwalten'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
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

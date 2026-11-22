import '../widgets/tv_catalog_focus.dart';
import '../core/platform/device_layout.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/family_profile.dart';
import '../core/localization/app_localizations.dart';
import '../providers/family_session_provider.dart';
import '../services/family_profile_service.dart';
import 'family_profile_management_screen.dart';

class FamilyProfileSelectionScreen extends StatefulWidget {
  const FamilyProfileSelectionScreen({super.key});

  @override
  State<FamilyProfileSelectionScreen> createState() =>
      _FamilyProfileSelectionScreenState();
}

class _FamilyProfileSelectionScreenState
    extends State<FamilyProfileSelectionScreen> {
  String _t(String key) => AppLocalizations.of(context).t(key);

  final FamilyProfileService _profileService =
      FamilyProfileService();

  List<FamilyProfile> _profiles = [];

  bool _isLoading = true;
  bool _isSelecting = false;
  bool _isManaging = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (!mounted || _isManaging || _isSelecting) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await _profileService.loadProfiles();

      if (!mounted) return;

      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            _t('family_selection_load_failed');
      });
    }
  }

  Future<void> _openProfileManagement() async {
    if (!mounted ||
        _isManaging ||
        _isSelecting ||
        _isLoading) {
      return;
    }

    setState(() {
      _isManaging = true;
      _errorMessage = null;
    });

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const FamilyProfileManagementScreen(),
        ),
      );
    } catch (_) {
      _showMessage(
        _t('family_selection_manage_failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isManaging = false;
        });
        await _loadProfiles();
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectProfile(
    FamilyProfile profile,
  ) async {
    if (!mounted ||
        _isSelecting ||
        _isManaging ||
        _isLoading) {
      return;
    }

    final session = context.read<FamilySessionProvider>();

    setState(() {
      _isSelecting = true;
      _errorMessage = null;
    });

    // Never reuse an earlier profile session.
    session.clearSession();

    try {
      String? parentPin;

      if (profile.type == FamilyProfileType.adult) {
        parentPin = await _requestParentPin(profile);

        if (!mounted || parentPin == null) {
          return;
        }
      }

      // The provider retains the adultPin parameter name
      // for compatibility. Its value is now the parent PIN.
      final activated = await session.activateProfile(
        profile,
        adultPin: parentPin,
      );

      if (!mounted) return;

      if (!activated || !session.isReady) {
        if (profile.type == FamilyProfileType.adult) {
          final openManagement =
              await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text(_t('family_profile_locked')),
                content: Text(_t('family_profile_unlock_failed')),
                actions: [
                  TextButton(
                    autofocus: true,
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop(false);
                    },
                    child: Text(_t('player_close')),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop(true);
                    },
                    child: Text(_t('family_manage')),
                  ),
                ],
              );
            },
          );

          if (!mounted) return;

          if (openManagement == true) {
            setState(() {
              _isSelecting = false;
            });

            await _openProfileManagement();
          }
        } else {
          _showMessage(
            _t('family_selection_child_failed'),
          );
        }
        return;
      }

      // When opened from Settings, return to the caller.
      // When used as the startup route, the app gate
      // handles navigation after session activation.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(
          session.activeProfile,
        );
      }
    } catch (_) {
      _showMessage(
        _t('family_selection_activation_failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
      }
    }
  }

  Future<String?> _requestParentPin(FamilyProfile profile) async {
    final pinController = TextEditingController();
    final pinFocus = FocusNode();
    final isTv = DeviceLayout.isTelevision;
    bool showPin = false;
    String? errorMessage;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            void submit() {
              final value = pinController.text.trim();
              if (!RegExp(r'^[0-9]{6,10}$').hasMatch(value)) {
                updateDialog(() => errorMessage =
                    _t('family_selection_pin_length'));
                return;
              }
              Navigator.of(dialogContext).pop(value);
            }

            void appendDigit(String digit) {
              if (pinController.text.length >= 10) return;
              updateDialog(() {
                pinController.text += digit;
                errorMessage = null;
              });
            }

            void deleteDigit() {
              if (pinController.text.isEmpty) return;
              updateDialog(() {
                pinController.text = pinController.text.substring(
                  0, pinController.text.length - 1,
                );
                errorMessage = null;
              });
            }

            Widget pinDetails() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.admin_panel_settings_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_t('family_selection_pin_title'),
                    style: Theme.of(dialogContext).textTheme.titleLarge)),
                ]),
                const SizedBox(height: 16),
                Text(_t('family_selection_unlock_adult').replaceAll('{name}', profile.displayName)),
                const SizedBox(height: 8),
                Text(_t('family_selection_pin_hint')),
                const SizedBox(height: 18),
                if (isTv)
                  Semantics(
                    label: _t('family_selection_pin_digits').replaceAll('{count}', '${pinController.text.length}'),
                    child: InkWell(
                      canRequestFocus: true,
                      onTap: () {
                        // TV uses the always-visible keypad, not the system IME.
                        FocusScope.of(dialogContext).nextFocus();
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _t('family_parent_pin'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          showPin ? pinController.text :
                            '●' * pinController.text.length,
                          style: Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: pinController,
                    focusNode: pinFocus,
                    autofocus: true,
                    obscureText: !showPin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _t('family_parent_pin'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        updateDialog(() => errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => submit(),
                  ),
                CheckboxListTile(
                  value: showPin,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_t('family_show_pin')),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      updateDialog(() => showPin = value ?? false),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  )),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(_t('family_selection_cancel')),
                    ),
                    FilledButton.icon(
                      onPressed: submit,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: Text(_t('family_unlock')),
                    ),
                  ],
                ),
              ],
            );

            Widget keypad() {
              final keys = ['1', '2', '3', '4', '5', '6',
                '7', '8', '9', '⌫', '0', '✓'];
              return SizedBox(
                width: 260,
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.45,
                    ),
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      return FilledButton.tonal(
                        autofocus: index == 0,
                        onPressed: () {
                          if (key == '⌫') {
                            deleteDigit();
                          } else if (key == '✓') {
                            submit();
                          } else {
                            appendDigit(key);
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(key, style: const TextStyle(fontSize: 23)),
                      );
                    },
                  ),
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: isTv
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 790),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: pinDetails()),
                            const SizedBox(width: 28),
                            keypad(),
                          ],
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: pinDetails(),
                      ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pinController.dispose();
        pinFocus.dispose();
      });
    }
  }

  IconData _profileIcon(FamilyProfile profile) {
    return profile.type == FamilyProfileType.child
        ? Icons.child_care_rounded
        : Icons.person_rounded;
  }

  Color _profileColor(
    BuildContext context,
    FamilyProfile profile,
  ) {
    final colors = Theme.of(context).colorScheme;

    return profile.type == FamilyProfileType.child
        ? colors.tertiary
        : colors.primary;
  }

  Widget _buildProfileCard(FamilyProfile profile) {
    final color = _profileColor(context, profile);
    final isChild =
        profile.type == FamilyProfileType.child;

    return TvCatalogFocus(child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isSelecting || _isManaging
            ? null
            : () => _selectProfile(profile),
        canRequestFocus:
            !_isSelecting && !_isManaging,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor:
                    color.withValues(alpha: 0.14),
                child: Icon(
                  _profileIcon(profile),
                  color: color,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    isChild
                        ? Icons.shield_outlined
                        : Icons.lock_outline,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      isChild
                          ? _t('family_child')
                          : _t('family_adult'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
              if (profile.isDefault) ...[
                const SizedBox(height: 10),
                Text(
                  _t('family_default'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildEmptyContent() {
    return Center(
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
            Text(
              _t('family_selection_welcome'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _t('family_selection_empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isManaging
                  ? null
                  : _openProfileManagement,
              icon: const Icon(
                Icons.admin_panel_settings_outlined,
              ),
              label: Text(_t('family_selection_setup')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh),
              label: Text(_t('playlist_refresh')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading || _isManaging) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadProfiles,
                icon: const Icon(Icons.refresh),
                label: Text(_t('family_retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return _buildEmptyContent();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = DeviceLayout.isTelevision
            ? (width >= 1050 ? 4 : 3)
            : width >= 900
            ? 5
            : width >= 600
                ? 3
                : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                DeviceLayout.isTelevision ? 1.1 : (width >= 600 ? 1.05 : 0.82),
          ),
          itemCount: _profiles.length,
          itemBuilder: (context, index) {
            return _buildProfileCard(
              _profiles[index],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('family_who')),
        actions: [
          if (_profiles.isNotEmpty)
            IconButton(
              tooltip: _t('family_manage'),
              onPressed: _isLoading ||
                      _isSelecting ||
                      _isManaging
                  ? null
                  : _openProfileManagement,
              icon: const Icon(
                Icons.manage_accounts_outlined,
              ),
            ),
          IconButton(
            tooltip: _t('family_refresh'),
            onPressed: _isLoading ||
                    _isSelecting ||
                    _isManaging
                ? null
                : _loadProfiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSelecting || _isManaging)
              const LinearProgressIndicator(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }
}

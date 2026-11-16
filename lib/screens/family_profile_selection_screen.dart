
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/family_profile.dart';
import '../providers/family_session_provider.dart';
import '../services/family_profile_service.dart';

class FamilyProfileSelectionScreen extends StatefulWidget {
  const FamilyProfileSelectionScreen({
    super.key,
  });

  @override
  State<FamilyProfileSelectionScreen> createState() =>
      _FamilyProfileSelectionScreenState();
}

class _FamilyProfileSelectionScreenState
    extends State<FamilyProfileSelectionScreen> {
  final FamilyProfileService _profileService =
      FamilyProfileService();

  List<FamilyProfile> _profiles = [];

  bool _isLoading = true;
  bool _isSelecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;

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
            'Die Familienprofile konnten nicht '
            'geladen werden.';
      });
    }
  }

  Future<void> _selectProfile(
    FamilyProfile profile,
  ) async {
    if (_isSelecting) return;

    final session = context.read<FamilySessionProvider>();

    setState(() {
      _isSelecting = true;
      _errorMessage = null;
    });

    // Invalidate the previous family session before
    // any new profile can be selected.
    session.clearSession();

    try {
      String? adultPin;

      if (profile.type == FamilyProfileType.adult) {
        adultPin = await _requestAdultPin(profile);

        if (!mounted) return;

        if (adultPin == null) {
          return;
        }
      }

      // The provider reloads the profile from Supabase,
      // verifies adult PINs and loads child permissions.
      final activated = await session.activateProfile(
        profile,
        adultPin: adultPin,
      );

      if (!mounted) return;

      if (!activated) {
        _showMessage(
          'Das Profil konnte nicht aktiviert werden. '
          'Bitte prüfe die PIN und versuche es erneut.',
        );
        return;
      }

      // Preserve the existing navigation contract:
      // the calling screen receives the selected profile.
      Navigator.of(context).pop(
        session.activeProfile,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Bei der Profilaktivierung ist ein Fehler '
        'aufgetreten. Bitte erneut versuchen.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
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

  /// Collects the adult PIN without verifying it here.
  ///
  /// Verification is performed by FamilySessionProvider.
  /// This prevents duplicate PIN verification requests.
  Future<String?> _requestAdultPin(
    FamilyProfile profile,
  ) async {
    final pinController = TextEditingController();
    final pinFocus = FocusNode();

    bool showPin = false;
    String? errorMessage;

    try {
      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, updateDialog) {
              void submit() {
                final value = pinController.text;

                if (!RegExp(r'^[0-9]{4,12}$')
                    .hasMatch(value)) {
                  updateDialog(() {
                    errorMessage =
                        'Bitte eine gültige PIN eingeben.';
                  });
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              }

              return AlertDialog(
                title: const Text(
                  'Erwachsenenprofil entsperren',
                ),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'PIN für ${profile.displayName} '
                          'eingeben.',
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: pinController,
                          focusNode: pinFocus,
                          autofocus: true,
                          obscureText: !showPin,
                          keyboardType:
                              TextInputType.number,
                          textInputAction:
                              TextInputAction.done,
                          maxLength: 12,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly,
                          ],
                          decoration:
                              const InputDecoration(
                            labelText: 'Profil-PIN',
                            counterText: '',
                            prefixIcon:
                                Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => submit(),
                        ),
                        CheckboxListTile(
                          value: showPin,
                          contentPadding: EdgeInsets.zero,
                          title:
                              const Text('PIN anzeigen'),
                          controlAffinity:
                              ListTileControlAffinity
                                  .leading,
                          onChanged: (value) {
                            updateDialog(() {
                              showPin = value ?? false;
                            });
                          },
                        ),
                        if (errorMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 8,
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color:
                                    Theme.of(dialogContext)
                                        .colorScheme
                                        .error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop();
                    },
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: const Text('Entsperren'),
                  ),
                ],
              );
            },
          );
        },
      );

      return pin;
    } finally {
      // Release resources after the dialog has
      // completed its current frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          pinController.dispose();
          pinFocus.dispose();
        },
      );
    }
  }

  IconData _profileIcon(
    FamilyProfile profile,
  ) {
    if (profile.type == FamilyProfileType.child) {
      return Icons.child_care_rounded;
    }

    return Icons.person_rounded;
  }

  Color _profileColor(
    BuildContext context,
    FamilyProfile profile,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (profile.type == FamilyProfileType.child) {
      return colors.tertiary;
    }

    return colors.primary;
  }

  Widget _buildProfileCard(
    FamilyProfile profile,
  ) {
    final color = _profileColor(context, profile);
    final isChild =
        profile.type == FamilyProfileType.child;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isSelecting
            ? null
            : () => _selectProfile(profile),
        canRequestFocus: !_isSelecting,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
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
                          ? 'Kinderprofil'
                          : 'Erwachsenenprofil',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
              if (profile.isDefault) ...[
                const SizedBox(height: 10),
                const Text(
                  'Standardprofil',
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
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
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
                label:
                    const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Padding(
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
              const SizedBox(height: 12),
              const Text(
                'Richte zuerst die Eltern-PIN ein '
                'und erstelle anschließend '
                'ein Erwachsenenprofil.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _loadProfiles,
                icon: const Icon(Icons.refresh),
                label:
                    const Text('Aktualisieren'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 900
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
                width >= 600 ? 1.05 : 0.82,
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
        title: const Text(
          'Wer schaut gerade?',
        ),
        actions: [
          IconButton(
            tooltip: 'Profile aktualisieren',
            onPressed:
                _isLoading || _isSelecting
                    ? null
                    : _loadProfiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSelecting)
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


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/family_pin_service.dart';

/// First-time PIN setup for an adult family profile.
///
/// The parent access token must originate from
/// a successful server-side parent PIN verification.
///
/// A successful setup returns true to the caller.
/// Cancellation returns false.
///
/// Existing PINs cannot be overwritten through
/// this screen or its Supabase RPC.
class FamilyAdultPinSetupScreen extends StatefulWidget {
  final String familyProfileId;
  final String profileName;
  final String parentAccessToken;

  const FamilyAdultPinSetupScreen({
    super.key,
    required this.familyProfileId,
    required this.profileName,
    required this.parentAccessToken,
  });

  @override
  State<FamilyAdultPinSetupScreen> createState() =>
      _FamilyAdultPinSetupScreenState();
}

class _FamilyAdultPinSetupScreenState
    extends State<FamilyAdultPinSetupScreen> {
  final FamilyPinService _pinService = FamilyPinService();

  final TextEditingController _pinController =
      TextEditingController();

  final TextEditingController _confirmController =
      TextEditingController();

  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  final FocusNode _saveFocus = FocusNode();

  bool _busy = false;
  bool _showPin = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();

    _pinFocus.dispose();
    _confirmFocus.dispose();
    _saveFocus.dispose();

    super.dispose();
  }

  String _messageForStatus(String status) {
    switch (status) {
      case 'success':
        return 'Die Profil-PIN wurde eingerichtet.';

      case 'already_configured':
        return 'Für dieses Erwachsenenprofil ist '
            'bereits eine PIN eingerichtet.';

      case 'invalid_pin':
        return 'Die PIN muss aus 6 bis 12 '
            'Ziffern bestehen.';

      case 'invalid_profile':
        return 'Dieses Erwachsenenprofil ist '
            'nicht gültig oder gehört nicht '
            'zu deinem Konto.';

      case 'invalid_parent_session':
        return 'Die Eltern-PIN-Sitzung ist '
            'abgelaufen. Bitte die '
            'Familienverwaltung erneut entsperren.';

      case 'unauthorized':
        return 'Deine Anmeldung ist abgelaufen. '
            'Bitte erneut anmelden.';

      default:
        return 'Die PIN konnte nicht '
            'eingerichtet werden.';
    }
  }

  Future<void> _savePin() async {
    if (_busy) return;

    final pin = _pinController.text;
    final confirmation = _confirmController.text;

    if (!RegExp(r'^[0-9]{6,12}$').hasMatch(pin)) {
      setState(() {
        _error =
            'Die PIN muss aus 6 bis 12 Ziffern bestehen.';
      });
      return;
    }

    if (pin != confirmation) {
      setState(() {
        _error =
            'Die beiden PIN-Eingaben stimmen nicht überein.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final status = await _pinService.initializeAdultPin(
        parentAccessToken: widget.parentAccessToken,
        familyProfileId: widget.familyProfileId,
        newPin: pin,
      );

      if (!mounted) return;

      if (status == 'success') {
        // Do not retain the PIN in the input fields.
        _pinController.clear();
        _confirmController.clear();

        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _error = _messageForStatus(status);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Die Serververbindung ist fehlgeschlagen. '
            'Bitte versuche es erneut.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'PIN-Einrichtung abbrechen?',
          ),
          content: const Text(
            'Das Erwachsenenprofil bleibt bestehen, '
            'kann aber ohne eingerichtete PIN '
            'noch nicht entsperrt werden. '
            'Du kannst die PIN später in der '
            'Familienverwaltung einrichten.',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Zurück'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldLeave != true) return;

    Navigator.of(context).pop(false);
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_busy,
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      maxLength: 12,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_error != null && mounted) {
          setState(() {
            _error = null;
          });
        }
      },
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Erwachsenen-PIN einrichten',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Persönliche Profil-PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Richte für "${widget.profileName}" '
                      'eine eigene PIN ein. '
                      'Diese wird später benötigt, '
                      'um das Erwachsenenprofil '
                      'zu entsperren.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Die Erwachsenenprofil-PIN '
                      'ist unabhängig von der '
                      'Eltern-PIN.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    _buildPinField(
                      controller: _pinController,
                      focusNode: _pinFocus,
                      label: 'Neue PIN (6–12 Ziffern)',
                      onSubmitted: (_) {
                        _confirmFocus.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPinField(
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      label: 'PIN wiederholen',
                      onSubmitted: (_) {
                        _saveFocus.requestFocus();
                      },
                    ),
                    CheckboxListTile(
                      value: _showPin,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      title: const Text('PIN anzeigen'),
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() {
                                _showPin = value ?? false;
                              });
                            },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_busy)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      FilledButton.icon(
                        focusNode: _saveFocus,
                        onPressed: _savePin,
                        icon: const Icon(Icons.lock),
                        label: const Text(
                          'PIN sicher speichern',
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _cancel,
                      child: const Text(
                        'Später einrichten',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

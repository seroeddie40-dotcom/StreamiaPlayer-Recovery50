
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/family_pin_service.dart';

class FamilyParentPinSetupScreen extends StatefulWidget {
  const FamilyParentPinSetupScreen({
    super.key,
    this.onSetupComplete,
  });

  final VoidCallback? onSetupComplete;

  @override
  State<FamilyParentPinSetupScreen> createState() =>
      _FamilyParentPinSetupScreenState();
}

class _FamilyParentPinSetupScreenState
    extends State<FamilyParentPinSetupScreen> {
  final FamilyPinService _pinService = FamilyPinService();

  final TextEditingController _pinController =
      TextEditingController();

  final TextEditingController _confirmController =
      TextEditingController();

  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  final FocusNode _saveFocus = FocusNode();

  bool _isSaving = false;
  bool _showPin = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_isSaving) return;

    final pin = _pinController.text;
    final confirmation = _confirmController.text;

    if (!RegExp(r'^[0-9]{6,12}$').hasMatch(pin)) {
      setState(() {
        _errorMessage =
            'Die PIN muss aus 6 bis 12 Ziffern bestehen.';
      });
      return;
    }

    if (pin != confirmation) {
      setState(() {
        _errorMessage =
            'Die beiden PIN-Eingaben stimmen nicht überein.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final status =
          await _pinService.initializeParentPin(pin);

      if (!mounted) return;

      switch (status) {
        case 'success':
          _pinController.clear();
          _confirmController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Eltern-PIN wurde erfolgreich eingerichtet.',
              ),
            ),
          );

          if (widget.onSetupComplete != null) {
            widget.onSetupComplete!();
          } else {
            Navigator.of(context).pop(true);
          }
          return;

        case 'already_configured':
          setState(() {
            _errorMessage =
                'Für dieses Konto existiert bereits eine '
                'Eltern-PIN.';
          });
          break;

        case 'invalid_pin':
          setState(() {
            _errorMessage =
                'Ungültige PIN. Bitte 6 bis 12 Ziffern verwenden.';
          });
          break;

        case 'unauthorized':
          setState(() {
            _errorMessage =
                'Bitte melde dich erneut an.';
          });
          break;

        default:
          setState(() {
            _errorMessage =
                'Die PIN konnte nicht eingerichtet werden.';
          });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Verbindung zum Server fehlgeschlagen. '
            'Bitte erneut versuchen.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildPinField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputAction textInputAction,
    required VoidCallback onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      maxLength: 12,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      onSubmitted: (_) => onSubmitted(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eltern-PIN einrichten'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      Icon(
                        Icons.family_restroom,
                        size: 58,
                        color: theme.colorScheme.primary,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Familienprofile schützen',
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.headlineSmall,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Lege eine Eltern-PIN fest. '
                        'Damit schützt du die Verwaltung '
                        'der Familienprofile und die '
                        'Freigaben für Kinder.',
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      _buildPinField(
                        label: 'Neue Eltern-PIN',
                        controller: _pinController,
                        focusNode: _pinFocus,
                        textInputAction:
                            TextInputAction.next,
                        onSubmitted: () {
                          _confirmFocus.requestFocus();
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildPinField(
                        label: 'Eltern-PIN bestätigen',
                        controller: _confirmController,
                        focusNode: _confirmFocus,
                        textInputAction:
                            TextInputAction.done,
                        onSubmitted: () {
                          _saveFocus.requestFocus();
                        },
                      ),

                      CheckboxListTile(
                        value: _showPin,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _showPin = value ?? false;
                                });
                              },
                        title: const Text('PIN anzeigen'),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      FilledButton.icon(
                        focusNode: _saveFocus,
                        onPressed:
                            _isSaving ? null : _savePin,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline,
                              ),
                        label: Text(
                          _isSaving
                              ? 'PIN wird gespeichert ...'
                              : 'Eltern-PIN speichern',
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Bewahre deine PIN sicher auf. '
                        'Die Zurücksetzung wird später '
                        'über eine erneute '
                        'Identitätsprüfung abgesichert.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

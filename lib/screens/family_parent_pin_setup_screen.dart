
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/family_pin_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/platform/device_layout.dart';
import '../widgets/tv_pin_keypad.dart';

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
  String _t(String key) => AppLocalizations.of(context).t(key);

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
  bool _tvConfirming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

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

    if (!RegExp(r'^[0-9]{6,10}$').hasMatch(pin)) {
      setState(() {
        _errorMessage =
            _t('family_setup_pin_length');
      });
      return;
    }

    if (pin != confirmation) {
      setState(() {
        _errorMessage =
            _t('family_setup_pin_mismatch');
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
            SnackBar(
              content: Text(
                _t('family_setup_pin_saved'),
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
                _t('family_setup_pin_exists');
          });
          break;

        case 'invalid_pin':
          setState(() {
            _errorMessage =
                _t('family_setup_pin_invalid');
          });
          break;

        case 'unauthorized':
          setState(() {
            _errorMessage =
                _t('family_setup_pin_login');
          });
          break;

        default:
          setState(() {
            _errorMessage =
                _t('family_setup_pin_failed');
          });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            _t('family_setup_pin_network');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildTvPinSetup(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirming = _tvConfirming;
    final controller = isConfirming ? _confirmController : _pinController;
    return Scaffold(
      appBar: AppBar(title: Text(_t('family_setup_pin_setup'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.family_restroom, size: 48,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(_t('family_setup_pin_protect'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text(_t('family_setup_pin_intro'),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Text(isConfirming
                              ? _t('family_setup_pin_confirm')
                              : _t('family_setup_pin_new')),
                          const SizedBox(height: 8),
                          Semantics(
                            label: isConfirming
                                ? _t('family_setup_pin_confirm')
                                : _t('family_setup_pin_new'),
                            value: '${controller.text.length} digits',
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              child: Text(_showPin
                                  ? controller.text
                                  : '●' * controller.text.length),
                            ),
                          ),
                          CheckboxListTile(
                            value: _showPin,
                            title: Text(_t('family_setup_pin_show')),
                            onChanged: _isSaving ? null : (v) =>
                                setState(() => _showPin = v ?? false),
                          ),
                          if (_errorMessage != null)
                            Text(_errorMessage!,
                                style: TextStyle(color: theme.colorScheme.error)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _isSaving ? null : () {
                              if (_tvConfirming) {
                                setState(() {
                                  _tvConfirming = false;
                                  _errorMessage = null;
                                });
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                          ),
                          const SizedBox(height: 8),
                          Text(_t('family_setup_pin_note'),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : TvPinKeypad(
                              key: ValueKey(isConfirming),
                              autofocus: true,
                              value: controller.text,
                              maxLength: 10,
                              onChanged: (value) => setState(() {
                                controller.text = value;
                                _errorMessage = null;
                              }),
                              onSubmit: () {
                                if (!isConfirming) {
                                  if (!RegExp(r'^[0-9]{6,10}$')
                                      .hasMatch(_pinController.text)) {
                                    setState(() => _errorMessage =
                                        _t('family_setup_pin_length'));
                                    return;
                                  }
                                  setState(() {
                                    _tvConfirming = true;
                                    _errorMessage = null;
                                  });
                                } else {
                                  _savePin();
                                }
                              },
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
      autofocus: identical(focusNode, _pinFocus),
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      onEditingComplete: onSubmitted,

    );
  }

  @override
  Widget build(BuildContext context) {
    if (DeviceLayout.isTelevision) return _buildTvPinSetup(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('family_setup_pin_setup')),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
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
                        _t('family_setup_pin_protect'),
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.headlineSmall,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _t('family_setup_pin_intro'),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      _buildPinField(
                        label: _t('family_setup_pin_new'),
                        controller: _pinController,
                        focusNode: _pinFocus,
                        textInputAction:
                            TextInputAction.next,
                        onSubmitted: () {
                          if (!RegExp(r'^[0-9]{6,10}$').hasMatch(_pinController.text)) {
                            setState(() => _errorMessage = _t('family_setup_pin_length'));
                            _pinFocus.requestFocus();
                            return;
                          }
                          setState(() => _errorMessage = null);
                          _confirmFocus.requestFocus();
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildPinField(
                        label: _t('family_setup_pin_confirm'),
                        controller: _confirmController,
                        focusNode: _confirmFocus,
                        textInputAction:
                            TextInputAction.done,
                        onSubmitted: () {
                          if (_pinController.text != _confirmController.text) {
                            setState(() => _errorMessage = _t('family_setup_pin_mismatch'));
                            _confirmFocus.requestFocus();
                            return;
                          }
                          setState(() => _errorMessage = null);
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
                        title: Text(_t('family_setup_pin_show')),
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
                              ? _t('family_setup_pin_saving')
                              : _t('family_setup_pin_save'),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _t('family_setup_pin_note'),
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


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/prefs_service.dart';
import '../core/platform/device_layout.dart';

class ParentalLockScreen extends StatefulWidget {
  const ParentalLockScreen({super.key});

  @override
  State<ParentalLockScreen> createState() =>
      _ParentalLockScreenState();
}

class _ParentalLockScreenState
    extends State<ParentalLockScreen> {
  String _entered = '';
  bool _verified = false;
  bool _submitting = false;

  PrefsService? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final sharedPreferences =
          await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _prefs = PrefsService(sharedPreferences);
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die Kindersperre konnte nicht geladen werden.',
          ),
        ),
      );
    }
  }

  void _onDigit(String digit) {
    if (_prefs == null ||
        _submitting ||
        _verified ||
        _entered.length >= 4) {
      return;
    }

    setState(() {
      _entered += digit;
    });

    if (_entered.length == 4) {
      _submit();
    }
  }

  void _deleteLastDigit() {
    if (_entered.isEmpty || _submitting) return;

    setState(() {
      _entered = _entered.substring(
        0,
        _entered.length - 1,
      );
    });
  }

  void _clearPin() {
    if (_submitting) return;

    setState(() {
      _entered = '';
    });
  }

  Future<void> _submit() async {
    final prefs = _prefs;

    if (prefs == null ||
        _entered.length != 4 ||
        _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final existing = prefs.parentalPin;

      if (existing == null) {
        await prefs.setParentalPin(_entered);

        if (!mounted) return;

        setState(() {
          _verified = true;
          _entered = '';
        });
      } else if (existing == _entered) {
        if (!mounted) return;

        setState(() {
          _verified = true;
          _entered = '';
        });
      } else {
        if (!mounted) return;

        setState(() {
          _entered = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falsche PIN'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _entered = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die PIN konnte nicht verarbeitet werden.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kindersperre'),
      ),
      body: SafeArea(
        child: _prefs == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: _verified
                    ? _buildFolderList()
                    : _buildPinPad(),
              ),
      ),
    );
  }

  Widget _buildPinPad() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        final compact = availableHeight < 530;

        final horizontalPadding =
            availableWidth < 360 ? 12.0 : 20.0;

        final keypadWidth = (availableWidth -
                horizontalPadding * 2)
            .clamp(0.0, 280.0)
            .toDouble();

        final spacing = compact ? 7.0 : 12.0;

        final buttonSize =
            ((keypadWidth - spacing * 2) / 3)
                .clamp(36.0, compact ? 58.0 : 72.0)
                .toDouble();

        final actualKeypadWidth =
            buttonSize * 3 + spacing * 2;

        final pinBoxWidth =
            (buttonSize * 0.68)
                .clamp(28.0, 48.0)
                .toDouble();

        final pinBoxHeight =
            compact ? 42.0 : 58.0;

        final titleSize =
            compact ? 20.0 : 24.0;

        final titleGap =
            compact ? 10.0 : 24.0;

        final keypadGap =
            compact ? 12.0 : 28.0;

        return SingleChildScrollView(
          primary: false,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: compact ? 8 : 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                minHeight: availableHeight > 40
                    ? availableHeight -
                        (compact ? 16 : 40)
                    : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    _prefs!.parentalPin == null
                        ? 'PIN festlegen'
                        : 'PIN eingeben',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: titleGap),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled =
                          index < _entered.length;

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal:
                              compact ? 5 : 8,
                        ),
                        width: pinBoxWidth,
                        height: pinBoxHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline,
                          ),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          filled ? '●' : '',
                          style: TextStyle(
                            fontSize:
                                compact ? 20 : 28,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: keypadGap),
                  SizedBox(
                    width: actualKeypadWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var row = 0;
                            row < 3;
                            row++) ...[
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              for (var column = 0;
                                  column < 3;
                                  column++) ...[
                                if (column > 0)
                                  SizedBox(
                                    width: spacing,
                                  ),
                                _buildKey(
                                  label:
                                      '${row * 3 + column + 1}',
                                  size: buttonSize,
                                  autofocus:
                                      DeviceLayout.isTelevision &&
                                          row == 0 &&
                                          column == 0,
                                  onPressed: () =>
                                      _onDigit(
                                    '${row * 3 + column + 1}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: spacing),
                        ],
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _buildKey(
                              label: 'C',
                              icon: Icons.backspace_outlined,
                              size: buttonSize,
                              onPressed:
                                  _deleteLastDigit,
                            ),
                            SizedBox(width: spacing),
                            _buildKey(
                              label: '0',
                              size: buttonSize,
                              onPressed: () =>
                                  _onDigit('0'),
                            ),
                            SizedBox(width: spacing),
                            _buildKey(
                              label: 'Löschen',
                              icon: Icons.clear,
                              size: buttonSize,
                              onPressed: _clearPin,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_submitting) ...[
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKey({
    required String label,
    required double size,
    required VoidCallback onPressed,
    IconData? icon,
    bool autofocus = false,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(8),
          focusColor:
              colorScheme.primary.withValues(
            alpha: 0.28,
          ),
          onTap: _submitting ? null : onPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline,
              ),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: size * 0.34,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize:
                          size < 50 ? 20 : 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderList() {
    final prefs = _prefs!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 400;

        return Padding(
          padding: EdgeInsets.all(
            compact ? 12 : 24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Gesperrte Ordner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final folders =
                        prefs.lockedFolders;

                    if (folders.isEmpty) {
                      return const Center(
                        child: Text(
                          'Keine gesperrten Ordner',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder =
                            folders[index];

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            autofocus:
                                DeviceLayout.isTelevision &&
                                    index == 0,
                            focusColor:
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(
                                      alpha: 0.24,
                                    ),
                            onTap: () async {
                              final updated =
                                  List<String>.from(
                                prefs.lockedFolders,
                              )..remove(folder);

                              await prefs.setLockedFolders(
                                updated,
                              );

                              if (!mounted) return;

                              setState(() {});
                            },
                            child: ListTile(
                              leading:
                                  const Icon(Icons.lock),
                              title: Text(folder),
                              trailing: const Icon(
                                Icons.lock_open,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

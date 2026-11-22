import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/device_layout.dart';
import '../core/theme/app_theme.dart';

/// A single D-pad focus target for catalogue cards on Android TV.
///
/// A short OK opens the item; holding OK toggles its favorite state.
/// Touch/mobile interaction remains owned by the wrapped child.
class TvLongOkAction extends StatefulWidget {
  const TvLongOkAction({
    super.key,
    required this.child,
    required this.onShortPress,
    required this.onLongPress,
  });

  final Widget child;
  final VoidCallback onShortPress;
  final VoidCallback onLongPress;

  @override
  State<TvLongOkAction> createState() => _TvLongOkActionState();
}

class _TvLongOkActionState extends State<TvLongOkAction> {
  static const _holdDuration = Duration(milliseconds: 650);
  Timer? _holdTimer;
  bool _pressed = false;
  bool _longPressTriggered = false;
  bool _focused = false;

  bool _isConfirmKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  void _cancelPress() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pressed = false;
    _longPressTriggered = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_isConfirmKey(event.logicalKey)) return KeyEventResult.ignored;

    if (event is KeyDownEvent && !_pressed) {
      _pressed = true;
      _longPressTriggered = false;
      _holdTimer?.cancel();
      _holdTimer = Timer(_holdDuration, () {
        if (!mounted || !_pressed || !_focused ||
            ModalRoute.of(context)?.isCurrent != true) return;
        _longPressTriggered = true;
        widget.onLongPress();
      });
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent || (event is KeyDownEvent && _pressed)) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      if (!_pressed) return KeyEventResult.handled;
      final wasLongPress = _longPressTriggered;
      _cancelPress();
      if (!wasLongPress && mounted && _focused &&
          ModalRoute.of(context)?.isCurrent == true) {
        widget.onShortPress();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _cancelPress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!DeviceLayout.isTelevision) return widget.child;
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        if (!focused) _cancelPress();
        if (mounted && _focused != focused) {
          setState(() => _focused = focused);
        }
      },
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused ? AppTheme.electricBlue : Colors.transparent,
            width: 3,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

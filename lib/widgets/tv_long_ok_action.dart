import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/device_layout.dart';

/// Handles the TV remote's OK/Select key without triggering the short action
/// after a completed long press. Place this *outside* the actual focusable
/// card (InkWell, button, etc.). The card retains focus and touch behavior.
///
/// This widget does not persist favorites itself. Its [onLongPress] callback
/// must call the existing profile-scoped favorite service after access checks.
class TvLongOkAction extends StatefulWidget {
  const TvLongOkAction({
    super.key,
    required this.child,
    required this.onShortPress,
    required this.onLongPress,
    this.holdDuration = const Duration(seconds: 2),
  });

  final Widget child;
  final VoidCallback onShortPress;
  final VoidCallback onLongPress;
  final Duration holdDuration;

  @override
  State<TvLongOkAction> createState() => _TvLongOkActionState();
}

class _TvLongOkActionState extends State<TvLongOkAction> {
  Timer? _holdTimer;
  bool _pressed = false;
  bool _longTriggered = false;

  bool _isOk(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  void _cancelPress() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pressed = false;
    _longTriggered = false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isOk(event.logicalKey)) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (!_pressed) {
        _pressed = true;
        _longTriggered = false;
        _holdTimer?.cancel();
        _holdTimer = Timer(widget.holdDuration, () {
          if (!mounted || !_pressed || !node.hasFocus) return;
          _longTriggered = true;
          widget.onLongPress();
        });
      }
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (!_pressed) return KeyEventResult.handled;
      final shouldOpen = !_longTriggered;
      _cancelPress();
      if (shouldOpen) widget.onShortPress();
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
      canRequestFocus: true,
      skipTraversal: false,
      descendantsAreFocusable: false,
      onFocusChange: (focused) {
        if (!focused) _cancelPress();
      },
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

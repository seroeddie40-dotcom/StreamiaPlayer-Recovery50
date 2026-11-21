import 'package:flutter/material.dart';

import '../core/platform/device_layout.dart';
import '../core/theme/app_theme.dart';

/// Visual TV focus indicator for a card or row containing an actual focusable
/// control (for example InkWell). This wrapper deliberately does not request
/// focus itself: otherwise one remote-control step can land on a non-actionable
/// container instead of the actual item.
class TvCatalogFocus extends StatefulWidget {
  final Widget child;

  const TvCatalogFocus({super.key, required this.child});

  @override
  State<TvCatalogFocus> createState() => _TvCatalogFocusState();
}

class _TvCatalogFocusState extends State<TvCatalogFocus> {
  bool _focused = false;
  bool _scrollQueued = false;

  void _handleFocus(bool focused) {
    if (_focused != focused && mounted) {
      setState(() => _focused = focused);
    }
    if (!focused || _scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (!mounted || !_focused) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!DeviceLayout.isTelevision) return widget.child;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: true,
      onFocusChange: _handleFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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

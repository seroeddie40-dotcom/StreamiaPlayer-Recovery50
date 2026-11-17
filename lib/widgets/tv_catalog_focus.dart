import 'package:flutter/material.dart';
import '../core/platform/device_layout.dart';
import '../core/theme/app_theme.dart';

/// TV-only visible focus for cards and rows, including nested actions.
class TvCatalogFocus extends StatefulWidget {
  final Widget child;
  const TvCatalogFocus({super.key, required this.child});

  @override
  State<TvCatalogFocus> createState() => _TvCatalogFocusState();
}

class _TvCatalogFocusState extends State<TvCatalogFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!DeviceLayout.isTelevision) return widget.child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _focused = focused);
        if (focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_focused || ModalRoute.of(context)?.isCurrent != true) return;
            if (Scrollable.maybeOf(context) != null) {
              Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 120));
            }
          });
        }
      },
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _focused ? AppTheme.electricBlue : Colors.transparent, width: 3),
        ),
        child: widget.child,
      ),
    );
  }
}

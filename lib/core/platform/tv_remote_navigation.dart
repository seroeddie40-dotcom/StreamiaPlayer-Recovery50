import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'device_layout.dart';

/// Fallback shortcuts at the application level. Local player and keyboard
/// handlers get first refusal through Flutter's normal focus propagation.
class TvRemoteNavigation {
  TvRemoteNavigation._();

  static Map<ShortcutActivator, Intent> get shortcuts => {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const DirectionalFocusIntent(TraversalDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const DirectionalFocusIntent(TraversalDirection.down),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const DirectionalFocusIntent(TraversalDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const DirectionalFocusIntent(TraversalDirection.right),
        const SingleActivator(LogicalKeyboardKey.select, includeRepeats: false):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
            const ActivateIntent(),
      };

  static ThemeData theme(ThemeData base) {
    if (!DeviceLayout.isTelevision) return base;
    final focus = AppTheme.electricBlue.withOpacity(0.35);
    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.focused)) return focus;
      return null;
    });
    final style = ButtonStyle(overlayColor: overlay);
    return base.copyWith(
      focusColor: focus,
      filledButtonTheme: FilledButtonThemeData(style: base.filledButtonTheme.style?.merge(style) ?? style),
      outlinedButtonTheme: OutlinedButtonThemeData(style: base.outlinedButtonTheme.style?.merge(style) ?? style),
      textButtonTheme: TextButtonThemeData(style: base.textButtonTheme.style?.merge(style) ?? style),
      elevatedButtonTheme: ElevatedButtonThemeData(style: base.elevatedButtonTheme.style?.merge(style) ?? style),
      iconButtonTheme: IconButtonThemeData(style: base.iconButtonTheme.style?.merge(style) ?? style),
    );
  }
}

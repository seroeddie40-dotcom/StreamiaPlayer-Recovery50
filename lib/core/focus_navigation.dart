
import 'package:flutter/material.dart';

import 'platform/device_layout.dart';

/// Opens a detail route and restores the previous TV remote focus after pop.
///
/// Mobile touch screens do not need a forced focus restoration, which could
/// otherwise reopen the software keyboard unexpectedly.
Future<T?> pushWithFocusRestore<T>(BuildContext context, Route<T> route) async {
  if (!DeviceLayout.isTelevision) {
    return Navigator.of(context).push<T>(route);
  }

  final previousFocus = FocusManager.instance.primaryFocus;
  final previousScope = FocusScope.of(context);
  final navigator = Navigator.of(context);
  final parentRoute = ModalRoute.of(context);
  final result = await navigator.push<T>(route);

  if (!context.mounted) return result;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // A different route may have opened while the previous one was closing.
    if (!context.mounted || parentRoute?.isCurrent != true) return;

    final scopeContext = previousScope.context;
    if (scopeContext == null || !scopeContext.mounted) return;

    bool validInOriginalScope(FocusNode? node) {
      final nodeContext = node?.context;
      return node != null &&
          node.canRequestFocus &&
          nodeContext != null &&
          nodeContext.mounted &&
          _isInsideScope(nodeContext, scopeContext) &&
          // A navigator focus scope can also contain dialogs or other routes.
          // Only restore a control belonging to the route we just returned to.
          ModalRoute.of(nodeContext) == parentRoute;
    }

    // Prefer the exact item, then a surviving item in the same scope.
    // Never call nextFocus() to search: it changes global focus before we
    // can validate the candidate and can accidentally leave this screen.
    FocusNode? target;
    if (validInOriginalScope(previousFocus)) {
      target = previousFocus;
    } else if (validInOriginalScope(previousScope.focusedChild)) {
      target = previousScope.focusedChild;
    } else {
      for (final candidate in previousScope.traversalDescendants) {
        if (validInOriginalScope(candidate)) {
          target = candidate;
          break;
        }
      }
    }

    // An empty scope has no safe child to restore; do not steal focus.

    if (target == null) return;
    // Focus can move while this frame callback is pending. Do not override
    // another route, popup or dialog that became active in the meantime.
    if (parentRoute?.isCurrent != true) return;
    if (target != FocusManager.instance.primaryFocus) {
      target.requestFocus();
    }

    final targetContext = target.context;
    if (targetContext != null &&
        targetContext.mounted &&
        Scrollable.maybeOf(targetContext) != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 180),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  });

  return result;
}

/// Verify that fallback traversal stayed inside the original screen scope.
bool _isInsideScope(BuildContext child, BuildContext scope) {
  var found = false;
  child.visitAncestorElements((element) {
    if (element == scope) {
      found = true;
      return false;
    }
    return true;
  });
  return found || child == scope;
}

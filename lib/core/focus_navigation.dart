import 'package:flutter/material.dart';

/// Pushes a route and restores the previously focused control when it closes.
/// Flutter's route FocusScope already handles most restoration; this explicit
/// fallback also covers screens whose content rebuilds while a child route is
/// open (for example after a refresh or provider update).
Future<T?> pushWithFocusRestore<T>(BuildContext context, Route<T> route) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = await Navigator.of(context).push<T>(route);

  if (context.mounted &&
      previousFocus != null &&
      previousFocus.context != null &&
      previousFocus.canRequestFocus) {
    previousFocus.requestFocus();
  }

  return result;
}

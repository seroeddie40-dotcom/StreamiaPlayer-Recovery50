import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.darkBg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 120, height: 120,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.accentGradient,
          boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(.45), blurRadius: 36, spreadRadius: 8)]),
        child: const Center(child: Text('S', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)))),
      const SizedBox(height: 28),
      const Text('Streamia Player', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
      const SizedBox(height: 24),
      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
    ])),
  );
}

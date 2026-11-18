import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class StreamiaBrandLogo extends StatelessWidget {
  final double size;

  const StreamiaBrandLogo({
    super.key,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricBlue.withOpacity(0.45),
            blurRadius: size * 0.30,
            spreadRadius: size / 15,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            fontSize: size * 64 / 120,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StreamiaBrandLogo(),
            const SizedBox(height: 28),
            const Text(
              'Streamia Player',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

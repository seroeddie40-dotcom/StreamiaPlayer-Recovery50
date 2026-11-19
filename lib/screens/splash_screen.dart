import 'package:flutter/material.dart';

class StreamiaBrandLogo extends StatelessWidget {
  final double size;
  const StreamiaBrandLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/streamia_logo.png',
    width: size, height: size, fit: BoxFit.contain,
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: Center(child: SizedBox.expand(child: Image.asset(
        landscape ? 'assets/images/streamia_splash_tv.jpg'
            : 'assets/images/streamia_splash_mobile.jpg',
        fit: BoxFit.contain,
      ))),
    );
  }
}

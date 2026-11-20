import 'package:flutter/material.dart';

class StreamiaBrandLogo extends StatelessWidget {
  final double size;

  const StreamiaBrandLogo({
    super.key,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/streamia_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.play_circle_outline_rounded,
          size: size,
          color: const Color(0xFF20D9EC),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Widget _fallback() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamiaBrandLogo(size: 120),
          SizedBox(height: 20),
          Text(
            'STREAMIA PLAYER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) ==
            Orientation.landscape;

    final asset = landscape
        ? 'assets/images/streamia_splash_tv.jpg'
        : 'assets/images/streamia_splash_mobile.jpg';

    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: SizedBox.expand(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (
            context,
            child,
            frame,
            wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }

            return const ColoredBox(color: Color(0xFF020B18));
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'Streamia splash image failed: $asset',
            );

            return _fallback();
          },
        ),
      ),
    );
  }
}

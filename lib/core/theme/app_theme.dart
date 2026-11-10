import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color electricBlue = Color(0xFF00B4FF);
  static const Color teal = Color(0xFF00E5C3);
  static const Color aqua = Color(0xFF00FFF0);
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkSurface = Color(0xFF141A2E);
  static const Color lightBg = Color(0xFFF5F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [electricBlue, teal, aqua],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: electricBlue,
          secondary: teal,
          surface: darkSurface,
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardTheme(
          color: darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          elevation: 0,
          centerTitle: false,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        colorScheme: const ColorScheme.light(
          primary: electricBlue,
          secondary: teal,
          surface: lightSurface,
          onPrimary: Colors.white,
          onSurface: Color(0xFF1A1D2E),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        cardTheme: CardTheme(
          color: lightSurface,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFF1A1D2E)),
        ),
      );
}

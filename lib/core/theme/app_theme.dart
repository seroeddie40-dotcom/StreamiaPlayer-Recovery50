
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Streamia branding
  static const Color electricBlue = Color(0xFF00B4FF);
  static const Color teal = Color(0xFF00E5C3);
  static const Color aqua = Color(0xFF00FFF0);

  // Existing dark mode - unchanged
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkSurface = Color(0xFF141A2E);

  // New hybrid light mode
  static const Color lightBg = Color(0xFFC7CFD7);
  static const Color lightSurface = Color(0xFFDCE3E9);
  static const Color lightText = Color(0xFF263D50);
  static const Color lightBorder = Color(0xFFC8D8E3);

  // Premium dark cards used in the light dashboard
  static const Color hybridCard = Color(0xFF18232F);
  static const Color hybridCardText = Colors.white;
  static const Color hybridAccent = Color(0xFF32B6E7);

  static LinearGradient get accentGradient =>
      const LinearGradient(
        colors: [
          electricBlue,
          teal,
          aqua,
        ],
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
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        cardTheme: CardThemeData(
          color: darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          onSurface: lightText,
          outline: lightBorder,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: lightText,
          displayColor: lightText,
        ),
        cardTheme: CardThemeData(
          color: lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: lightBorder,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          foregroundColor: lightText,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: lightText,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: lightBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: electricBlue,
              width: 2,
            ),
          ),
        ),
        dividerColor: lightBorder,
      );
}

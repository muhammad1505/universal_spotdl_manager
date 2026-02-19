import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core Interface Colors
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color spotifyBlack = Color(0xFF191414);
  static const Color spotifyDarkGray = Color(0xFF121212);
  static const Color spotifyLightGray = Color(0xFF535353);
  static const Color spotifyWhite = Color(0xFFFFFFFF);
  
  // Extended Palette for Professional Look
  static const Color surfaceColor = Color(0xFF1E2125);
  static const Color errorColor = Color(0xFFE91429);
  static const Color warningColor = Color(0xFFF57F17);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white10, Colors.white12],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: spotifyGreen,
      scaffoldBackgroundColor: spotifyDarkGray,
      colorScheme: const ColorScheme.dark(
        primary: spotifyGreen,
        secondary: spotifyLightGray,
        surface: spotifyBlack,
        onPrimary: spotifyWhite,
        onSurface: spotifyWhite,
        error: errorColor,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: spotifyWhite,
        displayColor: spotifyWhite,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0, 
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: spotifyGreen,
          foregroundColor: spotifyWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: spotifyGreen, width: 2),
        ),
        hintStyle: TextStyle(color: spotifyWhite.withValues(alpha: 0.5)),
      ),
      iconTheme: const IconThemeData(
        color: spotifyWhite,
        size: 24,
      ),
    );
  }
}

// lib/src/core/theme/main_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// First, let's define our color palette
class AppColors {
  static const Color primaryGreen = Color(0xFF2E7D32); // A rich, deep green
  static const Color darkGreen = Color(
    0xFF1A3A3A,
  ); // For buttons, like in the login
  static const Color background = Color(0xFFF5F5F5); // Light grey background
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF888888);
  static const Color inputFill = Color(0xFFFFFFFF); // White
  static const Color accentYellow = Color(0xFFFFC107);
}

// Now, we create our master theme data
final ThemeData mainTheme = ThemeData(
  // Color Scheme
  primaryColor: AppColors.primaryGreen,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryGreen,
    secondary: AppColors.darkGreen,
    surface: AppColors.cardBackground,
    background: AppColors.background,
    error: Colors.red,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textDark,
    onBackground: AppColors.textDark,
    onError: Colors.white,
  ),

  // Font and Text Theme
  textTheme: GoogleFonts.poppinsTextTheme().copyWith(
    // Example: For "Hello, Good Morning"
    headlineLarge: GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.textDark,
    ),
    // Example: For card titles or section headers
    headlineMedium: GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.textDark,
    ),
    // For general content
    bodyLarge: GoogleFonts.poppins(fontSize: 16, color: AppColors.textDark),
    // For subtitles or descriptions
    bodyMedium: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
    // For button text
    labelLarge: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),

  // ElevatedButton Theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.darkGreen,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),

  // InputDecoration Theme (for TextFields)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputFill,
    contentPadding: const EdgeInsets.symmetric(
      vertical: 15.0,
      horizontal: 20.0,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide.none,
    ),
    hintStyle: GoogleFonts.poppins(color: AppColors.textLight.withOpacity(0.8)),
  ),

  // Card Theme
  cardTheme: CardThemeData(
    color: AppColors.cardBackground,
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  ),

  // AppBar Theme
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: AppColors.textDark),
    titleTextStyle: GoogleFonts.poppins(
      color: AppColors.textDark,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
);

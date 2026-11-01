import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const surface2 = Color(0xFF1E1E1E);
  static const surface3 = Color(0xFF2A2A2A);
  static const red = Color(0xFFE50914);
  static const blue = Color(0xFF00D1FF);
  static const gold = Color(0xFFFFB800);
  static const green = Color(0xFF00E676);
  static const text = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF9E9E9E);
  static const tertiary = Color(0xFF5A5A5A);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.red,
      secondary: AppColors.blue,
      surface: AppColors.surface,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: Colors.white12,
    useMaterial3: true,
  );
}

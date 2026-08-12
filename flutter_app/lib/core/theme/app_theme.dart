import 'package:flutter/material.dart';

class AppColors {
  // Primary palette - deep navy blue
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2E5C9A);
  static const Color primaryDark = Color(0xFF112238);

  // Accent - amber/gold for automotive feel
  static const Color accent = Color(0xFFE8A020);
  static const Color accentLight = Color(0xFFF5C55A);
  static const Color accentDark = Color(0xFFB87B10);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF2980B9);

  // Neutrals
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F8);
  static const Color divider = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textDisabled = Color(0xFFCBD5E0);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnAccent = Colors.white;

  // Status chips
  static const Color lowStock = Color(0xFFFFF3CD);
  static const Color lowStockText = Color(0xFF856404);
  static const Color inStock = Color(0xFFD4EDDA);
  static const Color inStockText = Color(0xFF155724);

  // Gradient
  static const List<Color> primaryGradient = [primaryLight, primary];
  static const List<Color> accentGradient = [accentLight, accent];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Sora',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
  color: AppColors.surface,
  elevation: 2,
  shadowColor: Colors.black12,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Sora'),
        hintStyle: const TextStyle(color: AppColors.textDisabled, fontFamily: 'Sora'),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(fontFamily: 'Sora', fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        displayMedium: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineLarge: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.textPrimary),
        headlineMedium: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.textPrimary),
        headlineSmall: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Sora', fontSize: 15, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Sora', fontSize: 14, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontFamily: 'Sora', fontSize: 12, color: AppColors.textSecondary),
        labelLarge: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: 'Sora', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Sora', fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

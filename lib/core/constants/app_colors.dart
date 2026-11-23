import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Vibrant Green
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryLight = Color(0xFF81C784);
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primarySurface = Color(0xFF1B3A1D);

  // Accent - Electric Blue
  static const Color accent = Color(0xFF2196F3);
  static const Color accentLight = Color(0xFF64B5F6);
  static const Color accentDark = Color(0xFF1976D2);

  // Background - Deep Dark
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color backgroundMedium = Color(0xFF161B22);
  static const Color backgroundLight = Color(0xFF21262D);

  // Surface - Dark Cards
  static const Color surface = Color(0xFF1C2128);
  static const Color surfaceLight = Color(0xFF2D333B);
  static const Color surfaceBorder = Color(0xFF373E47);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8C4);
  static const Color textTertiary = Color(0xFF768390);
  static const Color textDisabled = Color(0xFF484F58);

  // Macro Colors
  static const Color protein = Color(0xFFFF6B6B);
  static const Color carbs = Color(0xFF4ECDC4);
  static const Color fat = Color(0xFFFFE66D);
  static const Color fiber = Color(0xFFA78BFA);
  static const Color sugar = Color(0xFFFF9FF3);
  static const Color water = Color(0xFF54A0FF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFFA78BFA),
    Color(0xFFFF9FF3),
    Color(0xFFFF9800),
  ];

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundDark, backgroundMedium],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF1C2128),
      Color(0xFF161B22),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient proteinGradient = LinearGradient(
    colors: [protein, Color(0xFFFF8E8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient carbsGradient = LinearGradient(
    colors: [carbs, Color(0xFF7EDDD6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fatGradient = LinearGradient(
    colors: [fat, Color(0xFFFFED99)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light theme colors
  static const Color backgroundLightTheme = Color(0xFFF5F7FA);
  static const Color surfaceLightTheme = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);
}

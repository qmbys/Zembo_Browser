import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF000000);
  static const chrome = Color(0xFF090A0C);
  static const field = Color(0xFF101215);
  static const tile = Color(0xFF111418);
  static const border = Color(0xFF252A30);
  static const muted = Color(0xFF8D969F);
  static const foreground = Color(0xFFF2F4F6);
  static const orange = Color(0xFFFF5A0A);
}

class AppTheme {
  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Segoe UI',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      surface: AppColors.chrome,
    ),
    useMaterial3: true,
  );
}

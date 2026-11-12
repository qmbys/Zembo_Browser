import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF000000);
  static const chrome = Color(0xFF090A0C);
  static const field = Color(0xFF101215);
  static const tile = Color(0xFF111418);
  static const panel = Color(0xFF181818);
  static const border = Color(0xFF252A30);
  static const muted = Color(0xFF8D969F);
  static const foreground = Color(0xFFF2F4F6);
  static const orange = Color(0xFFFF5A0A);
}

class AppTheme {
  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      surface: AppColors.chrome,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    // Всплывающие уведомления внизу — тёмные, в стиле браузера.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.panel,
      contentTextStyle:
          const TextStyle(color: AppColors.foreground, fontSize: 14),
      actionTextColor: AppColors.orange,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bannerTheme: const MaterialBannerThemeData(
      backgroundColor: AppColors.panel,
      contentTextStyle:
          TextStyle(color: AppColors.foreground, fontSize: 14),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.orange
              : const Color(0xFF2B3036)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.orange : null),
      checkColor: WidgetStateProperty.all(Colors.black),
    ),
    useMaterial3: true,
  );
}

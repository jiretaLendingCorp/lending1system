// lib/core/theme/app_theme.dart
// Jireta Loans & Credit Corp. 1996

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Poppins';

  // ─── Color Schemes ────────────────────────────────────────

  static ColorScheme get _lightColorScheme => const ColorScheme(
    brightness:     Brightness.light,
    primary:        AppColors.primary500,
    onPrimary:      Colors.white,
    primaryContainer: AppColors.primary100,
    onPrimaryContainer: AppColors.primary900,
    secondary:      AppColors.accent,
    onSecondary:    Colors.white,
    secondaryContainer: AppColors.accentLight,
    onSecondaryContainer: AppColors.accentDark,
    error:          AppColors.error,
    onError:        Colors.white,
    errorContainer: AppColors.errorLight,
    onErrorContainer: AppColors.errorDark,
    surface:        AppColors.lightSurface,
    onSurface:      AppColors.lightText,
    surfaceContainerHighest: AppColors.lightSurfaceVariant,
    onSurfaceVariant: AppColors.lightTextSecondary,
    outline:        AppColors.lightBorder,
    outlineVariant: AppColors.lightBorderLight,
    shadow:         Colors.black,
    scrim:          Colors.black,
    inverseSurface:       AppColors.darkSurface,
    onInverseSurface:     AppColors.darkText,
    inversePrimary:       AppColors.primary300,
  );

  static ColorScheme get _darkColorScheme => const ColorScheme(
    brightness:     Brightness.dark,
    primary:        AppColors.primary400,
    onPrimary:      AppColors.primary900,
    primaryContainer: AppColors.primary800,
    onPrimaryContainer: AppColors.primary100,
    secondary:      AppColors.accent,
    onSecondary:    AppColors.primary900,
    secondaryContainer: AppColors.accentDark,
    onSecondaryContainer: AppColors.accentLight,
    error:          AppColors.error,
    onError:        Colors.white,
    errorContainer: AppColors.errorDark,
    onErrorContainer: AppColors.errorLight,
    surface:        AppColors.darkSurface,
    onSurface:      AppColors.darkText,
    surfaceContainerHighest: AppColors.darkSurfaceVariant,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline:        AppColors.darkBorder,
    outlineVariant: AppColors.darkBorderLight,
    shadow:         Colors.black,
    scrim:          Colors.black,
    inverseSurface:       AppColors.lightSurface,
    onInverseSurface:     AppColors.lightText,
    inversePrimary:       AppColors.primary600,
  );

  // ─── Light Theme ──────────────────────────────────────────

  static ThemeData get lightTheme {
    final cs = _lightColorScheme;
    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      fontFamily:     _fontFamily,
      brightness:     Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        elevation:       0,
        scrolledUnderElevation: 1,
        shadowColor:     AppColors.primary500.withValues(alpha: 0.1),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarBrightness:      Brightness.light,
          statusBarIconBrightness:  Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          fontFamily:  _fontFamily,
          fontSize:    18,
          fontWeight:  FontWeight.w600,
          color:       AppColors.lightText,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation:   0,
        color:       AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.lightTextHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.primary500, fontSize: 12),
        prefixIconColor: AppColors.lightTextSecondary,
        suffixIconColor: AppColors.lightTextSecondary,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppColors.primary500,
          foregroundColor:  Colors.white,
          elevation:        0,
          padding:          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary500,
          side:            const BorderSide(color: AppColors.primary500),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary500,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor:      AppColors.lightSurfaceVariant,
        selectedColor:        AppColors.primary100,
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color:     AppColors.lightBorder,
        thickness: 1,
        space:     1,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.lightSurface,
        selectedItemColor:    AppColors.primary500,
        unselectedItemColor:  AppColors.lightTextSecondary,
        elevation:            0,
        type:                 BottomNavigationBarType.fixed,
        selectedLabelStyle:   TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontSize: 11),
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor:         AppColors.primary500,
        unselectedLabelColor: AppColors.lightTextSecondary,
        indicatorColor:     AppColors.primary500,
        labelStyle:         TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor:  WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AppColors.lightTextHint),
        trackColor:  WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary500 : AppColors.lightBorder),
      ),

      // Text Theme
      textTheme: _buildTextTheme(AppColors.lightText, AppColors.lightTextSecondary),
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────

  static ThemeData get darkTheme {
    final cs = _darkColorScheme;
    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      fontFamily:     _fontFamily,
      brightness:     Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation:       0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarBrightness:      Brightness.dark,
          statusBarIconBrightness:  Brightness.light,
        ),
        titleTextStyle: const TextStyle(
          fontFamily:  _fontFamily,
          fontSize:    18,
          fontWeight:  FontWeight.w600,
          color:       AppColors.darkText,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color:     AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.darkTextHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.primary400, fontSize: 12),
        prefixIconColor: AppColors.darkTextSecondary,
        suffixIconColor: AppColors.darkTextSecondary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary400,
          side: const BorderSide(color: AppColors.primary400),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder, thickness: 1, space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.darkSurface,
        selectedItemColor:    AppColors.primary400,
        unselectedItemColor:  AppColors.darkTextSecondary,
        elevation:            0,
        type:                 BottomNavigationBarType.fixed,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: _buildTextTheme(AppColors.darkText, AppColors.darkTextSecondary),
    );
  }

  // ─── Text Theme Builder ────────────────────────────────────

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 57, fontWeight: FontWeight.w700, color: primary),
      displayMedium: TextStyle(fontFamily: _fontFamily, fontSize: 45, fontWeight: FontWeight.w700, color: primary),
      displaySmall:  TextStyle(fontFamily: _fontFamily, fontSize: 36, fontWeight: FontWeight.w600, color: primary),
      headlineLarge: TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: primary),
      headlineMedium:TextStyle(fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: TextStyle(fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: primary),
      titleLarge:    TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      titleMedium:   TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge:     TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall:     TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelLarge:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium:   TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
      labelSmall:    TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
    );
  }
}
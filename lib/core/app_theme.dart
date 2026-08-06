
import 'package:flutter/material.dart';
import 'explorer_ui.dart';

class AppTheme {
  static const navy = ExplorerColors.navy;
  static const gold = ExplorerColors.gold;
  static const background = ExplorerColors.background;
  static const ink = ExplorerColors.text;

  // Backward-compatible aliases used by existing pages.
  static const heritage = ExplorerColors.navy;
  static const forest = ExplorerColors.gold;
  static const cream = ExplorerColors.background;

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: ExplorerColors.navy,
      onPrimary: Colors.white,
      secondary: ExplorerColors.gold,
      onSecondary: ExplorerColors.navyDark,
      error: ExplorerColors.danger,
      onError: Colors.white,
      surface: ExplorerColors.surface,
      onSurface: ExplorerColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ExplorerColors.background,
      canvasColor: ExplorerColors.background,
      dividerColor: ExplorerColors.border,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: ExplorerColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
        headlineMedium: TextStyle(
          color: ExplorerColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
        titleLarge: TextStyle(
          color: ExplorerColors.navy,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: ExplorerColors.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: ExplorerColors.text),
        bodyMedium: TextStyle(color: ExplorerColors.text),
        bodySmall: TextStyle(color: ExplorerColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ExplorerColors.surface,
        foregroundColor: ExplorerColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ExplorerColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.25,
        ),
        shape: Border(
          bottom: BorderSide(color: ExplorerColors.border),
        ),
      ),
      cardTheme: const CardThemeData(
        color: ExplorerColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: ExplorerColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: ExplorerColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle: TextStyle(
          color: ExplorerColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: Color(0xFF98A2B3)),
        prefixIconColor: ExplorerColors.muted,
        suffixIconColor: ExplorerColors.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ExplorerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ExplorerColors.navy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ExplorerColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ExplorerColors.danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: ExplorerColors.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ExplorerColors.navySoft,
          disabledForegroundColor: ExplorerColors.muted,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ExplorerColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: ExplorerColors.navy,
          side: const BorderSide(color: ExplorerColors.navy),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ExplorerColors.navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 70,
        backgroundColor: ExplorerColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ExplorerColors.gold,
        elevation: 12,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 10,
            color: ExplorerColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: ExplorerColors.navy, size: 21),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: ExplorerColors.surface,
        selectedColor: ExplorerColors.goldSoft,
        side: BorderSide(color: ExplorerColors.border),
        labelStyle: TextStyle(
          color: ExplorerColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ExplorerColors.navy,
        foregroundColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: ExplorerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ExplorerColors.navy,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}

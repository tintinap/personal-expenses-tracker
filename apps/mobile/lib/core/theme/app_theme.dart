import 'package:flutter/material.dart';

/// PRD §18 — Theming with light and dark mode support
class AppTheme {
  AppTheme._();

  // ── Design tokens ─────────────────────────────────────────
  static const _primarySeed = Color(0xFF378ADD);

  // ── Light theme ───────────────────────────────────────────
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
      // PRD tokens
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      indicatorColor: _primarySeed.withAlpha(30),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFFFFF),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primarySeed,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  // ── Dark theme ────────────────────────────────────────────
  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      indicatorColor: _primarySeed.withAlpha(40),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF2C2C2C),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primarySeed,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

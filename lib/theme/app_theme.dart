import 'package:flutter/material.dart';

class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color work;
  final Color rest;
  final Color success;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.work,
    required this.rest,
    required this.success,
  });
}

const _darkPalette = AppPalette(
  background: Color(0xFF10131A),
  surface: Color(0xFF1B2028),
  surfaceElevated: Color(0xFF232933),
  divider: Color(0xFF2A303B),
  textPrimary: Color(0xFFF3F1EC),
  textSecondary: Color(0xFF8B93A1),
  accent: Color(0xFF3FBF7F),
  work: Color(0xFFD85A30),
  rest: Color(0xFF378ADD),
  success: Color(0xFF3FBF7F),
);

const _lightPalette = AppPalette(
  background: Color(0xFFF7F7F5),
  surface: Color(0xFFFFFFFF),
  surfaceElevated: Color(0xFFEDEDEA),
  divider: Color(0xFFE0E0DC),
  textPrimary: Color(0xFF1B1D1F),
  textSecondary: Color(0xFF6B7178),
  accent: Color(0xFF1F9D5C),
  work: Color(0xFFC44E27),
  rest: Color(0xFF2A6FB0),
  success: Color(0xFF1F9D5C),
);

extension AppColorsContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).brightness == Brightness.dark ? _darkPalette : _lightPalette;
  String get mapTileUrl => Theme.of(this).brightness == Brightness.dark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  List<String> get mapTileSubdomains => const ['a', 'b', 'c', 'd'];
}

class AppTheme {
  AppTheme._();

  static const appDisplayName = 'SmartRun Coach';

  static ThemeData get darkThemeData => _buildTheme(Brightness.dark, _darkPalette);
  static ThemeData get lightThemeData => _buildTheme(Brightness.light, _lightPalette);

  static ThemeData _buildTheme(Brightness brightness, AppPalette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: Colors.white,
        secondary: p.work,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.work,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyMedium: TextStyle(color: p.textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: p.textSecondary, fontSize: 12),
      ),
    );
  }
}

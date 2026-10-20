import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color seed = Color(0xFF2F5BEA);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
        colorSchemeSeed: seed,
        brightness: brightness,
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}

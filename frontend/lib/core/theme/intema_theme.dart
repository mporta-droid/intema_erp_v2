import 'package:flutter/material.dart';

class IntemaColors {
  static const navy = Color(0xFF071E63);
  static const blue = Color(0xFF174EA6);
  static const yellow = Color(0xFFE9D513);
  static const lightGray = Color(0xFFF3F5F8);
  static const border = Color(0xFFD7DCE5);
  static const text = Color(0xFF1D2433);
}

class IntemaTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: IntemaColors.blue,
      primary: IntemaColors.navy,
      secondary: IntemaColors.yellow,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: IntemaColors.lightGray,
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: IntemaColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IntemaColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: IntemaColors.border),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFE9EEF7)),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
      ),
    );
  }
}

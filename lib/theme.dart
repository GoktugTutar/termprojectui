import 'package:flutter/material.dart';

const kBg       = Color(0xFF0A0A10);
const kSurface  = Color(0xFF12121A);
const kBorder   = Color(0xFF1E1E2D);
const kAccent   = Color(0xFF8B7CFF);
const kText1    = Color(0xFFE8E8F0);
const kText2    = Color(0xFF6B6B80);

const _lessonColors = [
  Color(0xFF8B7CFF), // violet
  Color(0xFF5AB6FF), // blue
  Color(0xFF4ECDC4), // teal
  Color(0xFFF2B14A), // amber
  Color(0xFFFF7CA8), // rose
  Color(0xFF5BD49B), // green
];

Color lessonColor(int id) => _lessonColors[id % _lessonColors.length];

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      surface: kSurface,
      primary: kAccent,
      onPrimary: Colors.white,
      secondary: kAccent,
      onSecondary: Colors.white,
      onSurface: kText1,
      outline: kBorder,
    ),
    cardColor: kSurface,
    dividerColor: kBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBorder.withAlpha(60),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent),
      ),
      labelStyle: const TextStyle(color: kText2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      modalBackgroundColor: kSurface,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kSurface,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1E1E2D),
      contentTextStyle: TextStyle(color: kText1),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kBorder,
      selectedColor: kAccent.withAlpha(40),
      labelStyle: const TextStyle(color: kText1),
      side: const BorderSide(color: kBorder),
    ),
  );
}

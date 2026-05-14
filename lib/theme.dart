import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  bool _isLight = false;

  bool get isLight => _isLight;
  ThemeMode get themeMode => _isLight ? ThemeMode.light : ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLight = prefs.getBool('light_mode_enabled') ?? false;
    notifyListeners();
  }

  Future<void> setLight(bool value) async {
    if (_isLight == value) return;
    _isLight = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('light_mode_enabled', value);
  }

  Future<void> toggle() => setLight(!_isLight);
}

final appTheme = AppThemeController();

Color get kBg => appTheme.isLight ? Color(0xFFF5F1FF) : Color(0xFF070719);
Color get kSurface => appTheme.isLight ? Color(0xEFFFFFFF) : Color(0xD00D0A24);
Color get kBorder => appTheme.isLight ? Color(0xFFB9A8FF) : Color(0xFF3D2D84);
Color get kAccent => appTheme.isLight ? Color(0xFF684CFF) : Color(0xFF8A6CFF);
Color get kText1 => appTheme.isLight ? Color(0xFF201A3A) : Color(0xFFF4F0FF);
Color get kText2 => appTheme.isLight ? Color(0xFF766CA0) : Color(0xFF9B8DCC);
Color get kCyan => appTheme.isLight ? Color(0xFF00A6C8) : Color(0xFF49E9FF);

final _lessonColors = [
  Color(0xFF8B7CFF), // violet
  Color(0xFF2F8FE8), // blue
  Color(0xFF23A69B), // teal
  Color(0xFFF2B14A), // amber
  Color(0xFFFF6F9E), // rose
  Color(0xFF2FAE70), // green
];

Color lessonColor(int id) => _lessonColors[id % _lessonColors.length];

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData _buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final surface = light ? Color(0xEFFFFFFF) : Color(0xD00D0A24);
  final border = light ? Color(0xFFB9A8FF) : Color(0xFF3D2D84);
  final accent = light ? Color(0xFF684CFF) : Color(0xFF8A6CFF);
  final text1 = light ? Color(0xFF201A3A) : Color(0xFFF4F0FF);
  final text2 = light ? Color(0xFF766CA0) : Color(0xFF9B8DCC);

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'monospace',
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: ThemeData(brightness: brightness, fontFamily: 'monospace')
        .textTheme
        .apply(bodyColor: text1, displayColor: text1, fontFamily: 'monospace'),
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: Color(0xFFFF5C7A),
      onError: Colors.white,
      surface: surface,
      onSurface: text1,
      outline: border,
    ),
    cardColor: surface,
    dividerColor: border,
    cardTheme: CardThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border),
      ),
    ),
    iconTheme: IconThemeData(color: accent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: border.withAlpha(light ? 95 : 60),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent),
      ),
      labelStyle: TextStyle(color: text2),
      hintStyle: TextStyle(color: text2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
    ),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: light ? Color(0xFF201A3A) : Color(0xFF141032),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: border,
      selectedColor: accent.withAlpha(40),
      labelStyle: TextStyle(color: text1),
      side: BorderSide(color: border),
    ),
  );
}

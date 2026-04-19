import 'package:flutter/material.dart';

// Provider managing app theme mode and toggles
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  
  // Current theme mode
  ThemeMode get themeMode => _themeMode;
  
  // Whether dark mode is active
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  // Toggle between dark and light modes
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  // Set to follow system theme
  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}
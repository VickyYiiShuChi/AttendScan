// lib/constants/app_colors.dart
import 'package:flutter/material.dart';

// Centralized color palette and dynamic getters for light/dark themes
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFF97B64);
  static const Color secondary = Color(0xFFFFA868);
  static const Color tertiary = Color(0xFFFFA477);
  static const Color background = Color(0xFFFFECE0);
  
  // Additional colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF333333);
  static const Color gray = Color(0xFF666666);
  static const Color lightGray = Color(0xFF999999);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF5F5F5);
  
  // Text colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFF999999);
  
  // Gradient colors
  static const List<Color> backgroundGradient = [
    Color(0xFFFFECE0),
    Color(0xFFFFA477),
    Color(0xFFFFA868),
  ];

  // ==================== Dark Mode Colors ====================
  
  // Dark mode primary colors
  static const Color primaryDark = Color(0xFFFF9B85);
  static const Color secondaryDark = Color(0xFFFFB794);
  static const Color tertiaryDark = Color(0xFFFFC5A3);
  static const Color backgroundDark = Color(0xFF121212);
  
  // Dark mode additional colors
  static const Color cardBackgroundDark = Color(0xFF1E1E1E);
  static const Color inputBackgroundDark = Color(0xFF2D2D2D);
  
  // Dark mode text colors
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color textHintDark = Color(0xFF707070);
  
  // Dark mode gradients
  static const List<Color> backgroundGradientDark = [
    Color(0xFF121212),
    Color(0xFF1A1A1A),
    Color(0xFF242424),
  ];

  // ==================== Dynamic color getters ====================
  
  // Get background color based on theme
  static Color getBackgroundColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? backgroundDark : background;
  }
  
  // Get card background color based on theme
  static Color getCardBackground(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? cardBackgroundDark : cardBackground;
  }
  
  // Get input background color based on theme
  static Color getInputBackground(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? inputBackgroundDark : inputBackground;
  }
  
  // Get primary color based on theme
  static Color getPrimaryColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? primaryDark : primary;
  }
  
  // Get secondary color based on theme
  static Color getSecondaryColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? secondaryDark : secondary;
  }
  
  // Get tertiary color based on theme
  static Color getTertiaryColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? tertiaryDark : tertiary;
  }
  
  // Get primary text color based on theme
  static Color getTextPrimary(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? textPrimaryDark : textPrimary;
  }
  
  // Get secondary text color based on theme
  static Color getTextSecondary(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? textSecondaryDark : textSecondary;
  }
  
  // Get hint text color based on theme
  static Color getTextHint(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? textHintDark : textHint;
  }
  
  // Get background gradient based on theme
  static List<Color> getBackgroundGradient(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? backgroundGradientDark : backgroundGradient;
  }
  
  // Get shadow color based on theme
  static Color getShadowColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? black.withOpacity(0.5) : black.withOpacity(0.1);
  }
}
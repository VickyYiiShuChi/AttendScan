import 'package:flutter/material.dart';
import 'app_colors.dart';

// Centralized text and input styles used throughout the app
class AppStyles {
  // Large display headline style
  static TextStyle get headlineLarge => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );
  
  // Medium display headline style
  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Small display headline style
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Large title style
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Medium title style
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Small title style
  static TextStyle get titleSmall => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Primary body text style
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  // Secondary body text style
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  // Small helper text style
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
  );
  
  // Button text style for large buttons
  static TextStyle get buttonLarge => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
  
  // Button text style for medium buttons
  static TextStyle get buttonMedium => const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
  
  // Standard input decoration for text fields
  static InputDecoration get inputDecoration => InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: AppColors.inputBackground,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 20,
    ),
    hintStyle: bodyMedium.copyWith(color: AppColors.textHint),
  );
}
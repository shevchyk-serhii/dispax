import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppStyles {
  AppStyles._();

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle glassHeadlineLarge = headlineLarge.copyWith(
    color: AppColors.glassText,
  );

  static TextStyle glassHeadlineMedium = headlineMedium.copyWith(
    color: AppColors.glassText,
  );

  static TextStyle glassTitleLarge = titleLarge.copyWith(
    color: AppColors.glassText,
  );

  static TextStyle glassTitleMedium = titleMedium.copyWith(
    color: AppColors.glassText,
  );

  static TextStyle glassBodyLarge = bodyLarge.copyWith(
    color: AppColors.glassText,
  );

  static TextStyle glassBodyMedium = bodyMedium.copyWith(
    color: AppColors.glassTextSecondary,
  );

  static TextStyle glassBodySmall = bodySmall.copyWith(
    color: AppColors.glassTextSecondary,
  );

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    elevation: 1,
  );

  static ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    side: const BorderSide(color: AppColors.primary),
  );

  static ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
  );

  static BoxDecoration primaryCardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowSm,
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Formerly a glass-morphism decoration; now a plain corporate card.
  // Kept under the same name so all existing call sites stay flat-styled.
  static BoxDecoration glassCardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    border: Border.all(color: AppColors.borderPrimary),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowSm,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static InputDecoration textFieldDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        borderSide: const BorderSide(color: AppColors.borderPrimary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        borderSide: const BorderSide(color: AppColors.borderPrimary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textLight),
    );
  }

  static BoxDecoration getGradientDecoration(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    );
  }

  static BoxDecoration getRoleGradientDecoration(String role) {
    List<Color> colors;
    switch (role.toLowerCase()) {
      case 'driver':
        colors = AppColors.driverGradient;
        break;
      case 'client':
        colors = AppColors.clientGradient;
        break;
      case 'secretary':
        colors = AppColors.secretaryGradient;
        break;
      case 'dispatcher':
        colors = AppColors.dispatcherGradient;
        break;
      default:
        colors = AppColors.primaryGradient;
    }
    return getGradientDecoration(colors);
  }

  static AppBarTheme appBarTheme = const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textOnPrimary,
    ),
  );
}
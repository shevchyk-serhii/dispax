import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),

      appBarTheme: AppStyles.appBarTheme,

      textTheme: const TextTheme(
        headlineLarge: AppStyles.headlineLarge,
        headlineMedium: AppStyles.headlineMedium,
        headlineSmall: AppStyles.headlineSmall,
        titleLarge: AppStyles.titleLarge,
        titleMedium: AppStyles.titleMedium,
        titleSmall: AppStyles.titleSmall,
        bodyLarge: AppStyles.bodyLarge,
        bodyMedium: AppStyles.bodyMedium,
        bodySmall: AppStyles.bodySmall,
        labelLarge: AppStyles.labelLarge,
        labelMedium: AppStyles.labelMedium,
        labelSmall: AppStyles.labelSmall,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppStyles.primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppStyles.outlinedButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppStyles.textButtonStyle,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        shadowColor: AppColors.shadowMedium,
        elevation: AppDimensions.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        margin: const EdgeInsets.all(AppDimensions.paddingSmall),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingMedium,
        ),
        labelStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textLight),
      ),

      dividerTheme: const DividerThemeData(
        thickness: AppDimensions.dividerThickness,
        indent: AppDimensions.dividerIndent,
        endIndent: AppDimensions.dividerIndent,
        color: AppColors.textLight,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppDimensions.cardElevationHigh,
        shape: CircleBorder(),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textLight;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return AppColors.surfaceVariant;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall / 2),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textSecondary;
        }),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primaryLight,
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: AppStyles.labelSmall,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textOnPrimary),
        actionTextColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Container buildGradientContainer({
    required Widget child,
    required List<Color> colors,
    List<double>? stops,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
          stops: stops,
        ),
      ),
      child: child,
    );
  }

  static Container buildRoleGradientContainer({
    required Widget child,
    required String role,
  }) {
    return buildGradientContainer(
      child: child,
      colors: _getRoleColors(role),
    );
  }

  static List<Color> _getRoleColors(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return AppColors.driverGradient;
      case 'client':
        return AppColors.clientGradient;
      case 'secretary':
        return AppColors.secretaryGradient;
      case 'dispatcher':
        return AppColors.dispatcherGradient;
      default:
        return AppColors.primaryGradient;
    }
  }

  static BoxDecoration get glassDecoration {
    return AppStyles.glassCardDecoration;
  }

  static BoxDecoration get cardDecoration {
    return AppStyles.primaryCardDecoration;
  }
}
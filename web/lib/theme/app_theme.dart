import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  // ─── Light Theme ───
  static ThemeData get theme => _build(Brightness.light);

  // ─── Dark Theme ───
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      // Material 3 inverts primary by brightness: dark themes need a *light*
      // primary so accents stay legible. The light theme keeps the graphite
      // brand color (so light is unchanged), while dark uses a near-white
      // graphite with a dark onPrimary. This is the single source of truth —
      // widgets must read colorScheme.primary, not AppColors.primary.
      primary: isDark ? AppColors.textPrimaryDark : AppColors.primary,
      onPrimary: isDark ? AppColors.primary : Colors.white,
      primaryContainer: isDark ? AppColors.brand700 : AppColors.primarySurface,
      onPrimaryContainer: isDark ? AppColors.primaryLight : AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? AppColors.brand700 : const Color(0xFFE0F2FE),
      onSecondaryContainer: isDark ? AppColors.accentLight : AppColors.accentDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF2A0E0E) : const Color(0xFFFEF2F2),
      onErrorContainer: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
      surface: isDark ? AppColors.surfaceDark : AppColors.surface,
      onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      surfaceContainerHighest: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      onSurfaceVariant: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      outline: isDark ? AppColors.borderDark : AppColors.borderPrimary,
      outlineVariant: isDark ? AppColors.borderSecondaryDark : AppColors.borderSecondary,
      scrim: Colors.black,
      inverseSurface: isDark ? AppColors.surface : AppColors.surfaceDark,
      onInverseSurface: isDark ? AppColors.textPrimary : AppColors.textPrimaryDark,
      inversePrimary: isDark ? AppColors.primaryDark : AppColors.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: AppStyles.headlineLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        headlineMedium: AppStyles.headlineMedium.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        headlineSmall: AppStyles.headlineSmall.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        titleLarge: AppStyles.titleLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        titleMedium: AppStyles.titleMedium.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        titleSmall: AppStyles.titleSmall.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        bodyLarge: AppStyles.bodyLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        bodyMedium: AppStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        bodySmall: AppStyles.bodySmall.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        labelLarge: AppStyles.labelLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        labelMedium: AppStyles.labelMedium.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        labelSmall: AppStyles.labelSmall.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: isDark
              ? AppColors.brand700
              : AppColors.primarySurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppDimensions.buttonHeightLarge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          elevation: isDark ? 0 : 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppDimensions.buttonHeightLarge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          side: BorderSide(color: colorScheme.primary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : AppColors.shadowMedium,
        elevation: isDark ? 0 : AppDimensions.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          side: isDark
              ? const BorderSide(color: AppColors.borderDark, width: 1)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.all(AppDimensions.paddingSmall),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        // In dark, borderDark == surfaceVariantDark (the fill), so the resting
        // border was invisible and fields blended into the surface. Use the
        // lighter borderSecondaryDark so the field outline reads against its
        // own fill, and accent the focused state with the cyan brand color.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderSecondaryDark : AppColors.borderPrimary,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderSecondaryDark : AppColors.borderPrimary,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.accent,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingMedium,
        ),
        labelStyle: AppStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        hintStyle: AppStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.textLightDark : AppColors.textLight,
        ),
      ),

      dividerTheme: DividerThemeData(
        thickness: AppDimensions.dividerThickness,
        indent: AppDimensions.dividerIndent,
        endIndent: AppDimensions.dividerIndent,
        color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: isDark ? AppColors.textLightDark : AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accent);
          }
          return IconThemeData(
            color: isDark ? AppColors.textLightDark : AppColors.textLight,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent);
          }
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textLightDark : AppColors.textLight,
          );
        }),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: AppDimensions.cardElevationHigh,
        shape: const CircleBorder(),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        circularTrackColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? AppColors.textLightDark : AppColors.textLight;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? AppColors.surfaceVariantDark : AppColors.surface;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall / 2),
        ),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderSecondary,
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.textPrimary,
        contentTextStyle: AppStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.textPrimaryDark : Colors.white,
        ),
        actionTextColor: AppColors.accentLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        ),
        titleTextStyle: AppStyles.titleLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
        ),
        elevation: isDark ? 4 : 8,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: AppStyles.labelMedium.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }

  // ─── Gradient helpers ───
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

  static BoxDecoration get glassDecoration => AppStyles.glassCardDecoration;
  static BoxDecoration get cardDecoration => AppStyles.primaryCardDecoration;
}

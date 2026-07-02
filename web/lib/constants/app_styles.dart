import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppStyles {
  AppStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
    color: AppColors.textPrimary,
  );

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
    fontSize: 22,
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
    fontWeight: FontWeight.w600,
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

  /// Uppercase "eyebrow" label (HANDOFF §4 — Label S, 11/600 with tracking).
  /// Use for the small all-caps section labels above headings/cards.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
    color: AppColors.textSecondary,
  );

  // Text styles for content placed over graphite / dark headers.
  static TextStyle onDarkHeadlineLarge = headlineLarge.copyWith(
    color: AppColors.onDarkText,
  );

  static TextStyle onDarkBodyLarge = bodyLarge.copyWith(
    color: AppColors.onDarkText,
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

  /// Theme-aware outlined button: foreground + border follow the brightness.
  /// The static [outlinedButtonStyle] hardcodes graphite (`AppColors.primary`),
  /// which collides with the dark `surfaceDark` and renders the label/border
  /// invisible in dark mode — use this factory from widgets instead.
  static ButtonStyle outlinedButtonStyleOf(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      side: BorderSide(color: primary),
    );
  }

  static ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
  );

  /// Theme-aware text button: foreground follows the brightness. The static
  /// [textButtonStyle] hardcodes graphite (`AppColors.primary`) which is
  /// unreadable on the dark surface — use this factory from widgets instead.
  static ButtonStyle textButtonStyleOf(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
    );
  }

  static ButtonStyle accentButtonStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
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

  /// Theme-aware card decoration. Use this from widgets instead of the static
  /// [primaryCardDecoration] so the surface follows the active brightness
  /// (white in light mode, graphite `surfaceDark` in dark mode).
  static BoxDecoration primaryCardDecorationOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowSm,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Flat corporate card: surface fill, hairline border, soft shadow.
  static BoxDecoration cardDecoration = BoxDecoration(
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

  /// Theme-aware variant of [cardDecoration] — surface and border follow
  /// the active brightness.
  static BoxDecoration cardDecorationOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      border: Border.all(
        color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowSm,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

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

  /// Theme-aware variant of [textFieldDecoration]: borders, labels and the
  /// focus ring follow the active brightness. The static version hardcodes the
  /// graphite focus border (`AppColors.primary`), which is invisible against
  /// the dark field surface — prefer this factory from widgets.
  static InputDecoration textFieldDecorationOf(
    BuildContext context, {
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppDimensions.radiusSmall);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: AppStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      hintStyle: AppStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
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

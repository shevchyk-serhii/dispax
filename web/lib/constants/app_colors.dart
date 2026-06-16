import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand / Primary — Graphite ───
  static const Color primary = Color(0xFF18181B); // Zinc 900 (graphite)
  static const Color primaryLight = Color(0xFF3F3F46); // Zinc 700
  static const Color primaryDark = Color(0xFF09090B); // Zinc 950
  static const Color primarySurface = Color(
    0xFFF4F4F5,
  ); // Zinc 100 (light bg tint)

  // ─── Accent (single corporate accent) ───
  static const Color accent = Color(0xFF0EA5E9); // Sky 500 (cyan)
  static const Color accentLight = Color(0xFF38BDF8); // Sky 400
  static const Color accentDark = Color(0xFF0284C7); // Sky 600

  // ─── Brand Core (Graphite ramp) ───
  static const Color brand900 = Color(0xFF09090B);
  static const Color brand800 = Color(0xFF18181B);
  static const Color brand700 = Color(0xFF27272A);
  static const Color brand600 = Color(0xFF3F3F46);

  // ─── Role Accent Colors — unified to corporate graphite ───
  // Role is conveyed by icon + label, not color.
  static const Color dispatcherColor = primary;
  static const Color driverColor = primary;
  static const Color secretaryColor = primary;
  static const Color clientColor = primary;
  static const Color superAdminColor = primary;

  // Role Light Backgrounds — unified neutral tint
  static const Color dispatcherLightBg = primarySurface;
  static const Color driverLightBg = primarySurface;
  static const Color secretaryLightBg = primarySurface;
  static const Color clientLightBg = primarySurface;

  // ─── Login / Splash Gradient — subtle graphite ramp ───
  static const List<Color> primaryGradient = [
    Color(0xFF27272A),
    Color(0xFF18181B),
    Color(0xFF09090B),
  ];

  // ─── Role Header Gradients — flat graphite (unified) ───
  static const List<Color> dispatcherGradient = [
    Color(0xFF18181B),
    Color(0xFF18181B),
    Color(0xFF18181B),
  ];

  static const List<Color> driverGradient = [
    Color(0xFF18181B),
    Color(0xFF18181B),
    Color(0xFF18181B),
  ];

  static const List<Color> secretaryGradient = [
    Color(0xFF18181B),
    Color(0xFF18181B),
    Color(0xFF18181B),
  ];

  static const List<Color> clientGradient = [
    Color(0xFF18181B),
    Color(0xFF18181B),
    Color(0xFF18181B),
  ];

  // ─── Role Vivid Gradients — deprecated/unused, unified to graphite ───
  static const List<Color> dispatcherVividGradient = primaryGradient;
  static const List<Color> driverVividGradient = primaryGradient;
  static const List<Color> secretaryVividGradient = primaryGradient;
  static const List<Color> clientVividGradient = primaryGradient;

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Semantic — soft backgrounds / borders / strong text (for info containers)
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);
  static const Color successStrong = Color(0xFF166534);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningStrong = Color(0xFF92400E);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorStrong = Color(0xFF991B1B);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);
  static const Color infoStrong = Color(0xFF1E40AF);

  // ─── Status Colors ───
  static const Color rideRequested = Color(0xFFF59E0B);
  static const Color rideAssigned = Color(0xFF3B82F6);
  static const Color rideInProgress = Color(0xFF14B8A6);
  static const Color rideCompleted = Color(0xFF10B981);
  static const Color rideCancelled = Color(0xFFEF4444);

  // Status — light backgrounds (light mode)
  static const Color rideRequestedBg = Color(0xFFFFFBEB);
  static const Color rideAssignedBg = Color(0xFFEFF6FF);
  static const Color rideInProgressBg = Color(0xFFF0FDFA);
  static const Color rideCompletedBg = Color(0xFFF0FDF4);
  static const Color rideCancelledBg = Color(0xFFFEF2F2);

  // Status — dark backgrounds (dark mode)
  static const Color rideRequestedBgDark = Color(0xFF292210);
  static const Color rideAssignedBgDark = Color(0xFF0F1E38);
  static const Color rideInProgressBgDark = Color(0xFF0D2620);
  static const Color rideCompletedBgDark = Color(0xFF0B2317);
  static const Color rideCancelledBgDark = Color(0xFF2A0E0E);

  static const Color rideRequestedBorder = Color(0xFFFCD34D);
  static const Color rideAssignedBorder = Color(0xFF93C5FD);
  static const Color rideInProgressBorder = Color(0xFF5EEAD4);
  static const Color rideCompletedBorder = Color(0xFF86EFAC);
  static const Color rideCancelledBorder = Color(0xFFFCA5A5);

  static const Color rideRequestedText = Color(0xFF92400E);
  static const Color rideAssignedText = Color(0xFF1E40AF);
  static const Color rideInProgressText = Color(0xFF115E59);
  static const Color rideCompletedText = Color(0xFF166534);
  static const Color rideCancelledText = Color(0xFF991B1B);

  // Status text — dark mode
  static const Color rideRequestedTextDark = Color(0xFFFBBF24);
  static const Color rideAssignedTextDark = Color(0xFF60A5FA);
  static const Color rideInProgressTextDark = Color(0xFF2DD4BF);
  static const Color rideCompletedTextDark = Color(0xFF34D399);
  static const Color rideCancelledTextDark = Color(0xFFF87171);

  // ─── Text Colors — Light ───
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textLight = Color(0xFFA1A1AA);
  static const Color textOnPrimary = Colors.white;

  // ─── Text Colors — Dark ───
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textLightDark = Color(0xFF71717A);

  // ─── Surface Colors — Light ───
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF4F4F5);

  // ─── Surface Colors — Dark ───
  static const Color backgroundDark = Color(0xFF09090B);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surfaceVariantDark = Color(0xFF27272A);

  // ─── Border Colors ───
  static const Color borderPrimary = Color(0xFFE4E4E7);
  static const Color borderSecondary = Color(0xFFD4D4D8);
  static const Color borderDark = Color(0xFF27272A);
  static const Color borderSecondaryDark = Color(0xFF3F3F46);

  // ─── Glass Effect ───
  static Color glassBackground = Colors.white.withValues(alpha: 0.12);
  static Color glassBorder = Colors.white.withValues(alpha: 0.18);
  static Color glassText = Colors.white.withValues(alpha: 0.9);
  static Color glassTextSecondary = Colors.white.withValues(alpha: 0.7);

  // ─── Shadows ───
  static Color shadowXs = Colors.black.withValues(alpha: 0.05);
  static Color shadowSm = Colors.black.withValues(alpha: 0.06);
  static Color shadowMd = Colors.black.withValues(alpha: 0.08);
  static Color shadowLg = Colors.black.withValues(alpha: 0.12);
  static Color shadowXl = Colors.black.withValues(alpha: 0.16);

  // Legacy aliases
  static Color shadowLight = shadowXs;
  static Color shadowMedium = shadowSm;
  static Color shadowDark = shadowMd;
}

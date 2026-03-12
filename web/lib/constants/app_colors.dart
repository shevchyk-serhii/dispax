import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand Core (Deep Navy) ───
  static const Color brand900 = Color(0xFF0A0E1A);
  static const Color brand800 = Color(0xFF1E293B);
  static const Color brand700 = Color(0xFF334155);
  static const Color brand600 = Color(0xFF475569);

  // Primary (Info Blue)
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // ─── Role Accent Colors ───
  static const Color dispatcherColor = Color(0xFFF59E0B); // Amber
  static const Color driverColor = Color(0xFF06B6D4);      // Cyan
  static const Color secretaryColor = Color(0xFF8B5CF6);   // Violet
  static const Color clientColor = Color(0xFF10B981);      // Emerald

  // Role Light Backgrounds
  static const Color dispatcherLightBg = Color(0xFFFFFBEB);
  static const Color driverLightBg = Color(0xFFECFEFF);
  static const Color secretaryLightBg = Color(0xFFF5F3FF);
  static const Color clientLightBg = Color(0xFFECFDF5);

  // ─── Login Gradient ───
  static const List<Color> primaryGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
    Color(0xFF020617),
  ];

  // ─── Role Header Gradients ───
  // Dispatcher: dark navy base (shared dark header style)
  static const List<Color> dispatcherGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
    Color(0xFF020617),
  ];

  // Driver: dark navy base
  static const List<Color> driverGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
    Color(0xFF020617),
  ];

  // Secretary: dark navy → violet
  static const List<Color> secretaryGradient = [
    Color(0xFF1E293B),
    Color(0xFF3B0764),
    Color(0xFF7C3AED),
  ];

  // Client: dark navy base
  static const List<Color> clientGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
    Color(0xFF020617),
  ];

  // ─── Role Vivid Gradients (for stat cards, accents) ───
  static const List<Color> dispatcherVividGradient = [
    Color(0xFFFBBF24),
    Color(0xFFD97706),
    Color(0xFF92400E),
  ];

  static const List<Color> driverVividGradient = [
    Color(0xFF22D3EE),
    Color(0xFF06B6D4),
    Color(0xFF155E75),
  ];

  static const List<Color> secretaryVividGradient = [
    Color(0xFFA78BFA),
    Color(0xFF8B5CF6),
    Color(0xFF5B21B6),
  ];

  static const List<Color> clientVividGradient = [
    Color(0xFF34D399),
    Color(0xFF10B981),
    Color(0xFF065F46),
  ];

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Status Colors ───
  static const Color rideRequested = Color(0xFFF59E0B);      // Amber
  static const Color rideAssigned = Color(0xFF3B82F6);        // Blue
  static const Color rideInProgress = Color(0xFF14B8A6);      // Teal
  static const Color rideCompleted = Color(0xFF22C55E);       // Green
  static const Color rideCancelled = Color(0xFFEF4444);       // Red

  static const Color rideRequestedBg = Color(0xFFFFFBEB);
  static const Color rideAssignedBg = Color(0xFFEFF6FF);
  static const Color rideInProgressBg = Color(0xFFF0FDFA);
  static const Color rideCompletedBg = Color(0xFFF0FDF4);
  static const Color rideCancelledBg = Color(0xFFFEF2F2);

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

  // ─── Text Colors ───
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);    // text-tertiary
  static const Color textOnPrimary = Colors.white;

  // ─── Surface Colors ───
  static const Color background = Color(0xFFF8FAFC);  // surface-secondary
  static const Color surface = Colors.white;            // surface-primary
  static const Color surfaceVariant = Color(0xFFF1F5F9); // surface-tertiary

  // ─── Border Colors ───
  static const Color borderPrimary = Color(0xFFE2E8F0);
  static const Color borderSecondary = Color(0xFFCBD5E1);

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

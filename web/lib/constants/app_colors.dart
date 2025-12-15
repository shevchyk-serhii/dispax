import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);

  static const Color driverColor = Colors.blue;
  static const Color clientColor = Colors.green;
  static const Color secretaryColor = Colors.purple;
  static const Color dispatcherColor = Colors.orange;

  static const List<Color> primaryGradient = [
    Color(0xFF1976D2),
    Color(0xFF1565C0),
    Color(0xFF1A237E),
  ];

  static const List<Color> driverGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1976D2),
  ];

  static const List<Color> clientGradient = [
    Color(0xFF66BB6A),
    Color(0xFF388E3C),
  ];

  static const List<Color> secretaryGradient = [
    Color(0xFFAB47BC),
    Color(0xFF7B1FA2),
  ];

  static const List<Color> dispatcherGradient = [
    Color(0xFFFF8F65),
    Color(0xFFF57C00),
  ];

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  static const Color rideRequested = Color(0xFFF57C00);
  static const Color rideAssigned = Color(0xFF1976D2);
  static const Color rideInProgress = Color(0xFF00695C);
  static const Color rideCompleted = Color(0xFF2E7D32);
  static const Color rideCancelled = Color(0xFFD32F2F);

  static final Color rideRequestedBg = const Color(0xFFFFF3E0);
  static final Color rideAssignedBg = const Color(0xFFE3F2FD);
  static final Color rideInProgressBg = const Color(0xFFE0F2F1);
  static final Color rideCompletedBg = const Color(0xFFE8F5E8);
  static final Color rideCancelledBg = const Color(0xFFFFEBEE);

  static final Color rideRequestedBorder = const Color(0xFFFFB74D);
  static final Color rideAssignedBorder = const Color(0xFF64B5F6);
  static final Color rideInProgressBorder = const Color(0xFF4DB6AC);
  static final Color rideCompletedBorder = const Color(0xFF81C784);
  static final Color rideCancelledBorder = const Color(0xFFE57373);

  static final Color rideRequestedText = const Color(0xFFE65100);
  static final Color rideAssignedText = const Color(0xFF0D47A1);
  static final Color rideInProgressText = const Color(0xFF004D40);
  static final Color rideCompletedText = const Color(0xFF1B5E20);
  static final Color rideCancelledText = const Color(0xFFB71C1C);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  static Color glassBackground = Colors.white.withValues(alpha: 0.1);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
  static Color glassText = Colors.white.withValues(alpha: 0.9);
  static Color glassTextSecondary = Colors.white.withValues(alpha: 0.7);

  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);
}
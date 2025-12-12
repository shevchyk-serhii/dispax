import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Role-based Colors
  static const Color driverColor = Colors.blue;
  static const Color clientColor = Colors.green;
  static const Color secretaryColor = Colors.purple;
  static const Color dispatcherColor = Colors.orange;

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF1976D2), // blue[600]
    Color(0xFF1565C0), // blue[800]
    Color(0xFF1A237E), // indigo[900]
  ];

  static const List<Color> driverGradient = [
    Color(0xFF42A5F5), // blue[400]
    Color(0xFF1976D2), // blue[600]
  ];

  static const List<Color> clientGradient = [
    Color(0xFF66BB6A), // green[400]
    Color(0xFF388E3C), // green[600]
  ];

  static const List<Color> secretaryGradient = [
    Color(0xFFAB47BC), // purple[400]
    Color(0xFF7B1FA2), // purple[600]
  ];

  static const List<Color> dispatcherGradient = [
    Color(0xFFFF8F65), // orange[400]
    Color(0xFFF57C00), // orange[600]
  ];

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Ride Status Colors - Modern, clean and professional
  static const Color rideRequested = Color(0xFFF57C00);    // warm orange
  static const Color rideAssigned = Color(0xFF1976D2);     // material blue
  static const Color rideInProgress = Color(0xFF00695C);   // teal
  static const Color rideCompleted = Color(0xFF2E7D32);    // success green
  static const Color rideCancelled = Color(0xFFD32F2F);    // material red

  // Status Background Colors (subtle and clean)
  static final Color rideRequestedBg = const Color(0xFFFFF3E0);   // light orange
  static final Color rideAssignedBg = const Color(0xFFE3F2FD);    // light blue
  static final Color rideInProgressBg = const Color(0xFFE0F2F1);  // light teal
  static final Color rideCompletedBg = const Color(0xFFE8F5E8);   // light green
  static final Color rideCancelledBg = const Color(0xFFFFEBEE);   // light red

  // Status Border Colors (subtle definition)
  static final Color rideRequestedBorder = const Color(0xFFFFB74D);  // soft orange
  static final Color rideAssignedBorder = const Color(0xFF64B5F6);   // soft blue
  static final Color rideInProgressBorder = const Color(0xFF4DB6AC); // soft teal
  static final Color rideCompletedBorder = const Color(0xFF81C784);  // soft green
  static final Color rideCancelledBorder = const Color(0xFFE57373);  // soft red

  // Status Text Colors (strong contrast for readability)
  static final Color rideRequestedText = const Color(0xFFE65100);   // dark orange
  static final Color rideAssignedText = const Color(0xFF0D47A1);    // dark blue
  static final Color rideInProgressText = const Color(0xFF004D40);  // dark teal
  static final Color rideCompletedText = const Color(0xFF1B5E20);   // dark green
  static final Color rideCancelledText = const Color(0xFFB71C1C);   // dark red

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;

  // Background Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Glass Morphism Colors
  static Color glassBackground = Colors.white.withValues(alpha: 0.1);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
  static Color glassText = Colors.white.withValues(alpha: 0.9);
  static Color glassTextSecondary = Colors.white.withValues(alpha: 0.7);

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);
}
import 'package:flutter/material.dart';
import '../modules/ride_management/models/ride.dart';
import '../constants/app_colors.dart';

/// Unified ride status styling system
/// Provides consistent colors, icons, and display text across the app
class RideStatusStyles {
  RideStatusStyles._();

  /// Get the main status color (for icons in some contexts)
  static Color getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequested;
      case RideStatus.assigned:
        return AppColors.rideAssigned;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
    }
  }

  /// Get background color for status containers
  static Color getStatusBackgroundColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequestedBg;
      case RideStatus.assigned:
        return AppColors.rideAssignedBg;
      case RideStatus.inProgress:
        return AppColors.rideInProgressBg;
      case RideStatus.completed:
        return AppColors.rideCompletedBg;
      case RideStatus.cancelled:
        return AppColors.rideCancelledBg;
    }
  }

  /// Get border color for status containers
  static Color getStatusBorderColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequestedBorder;
      case RideStatus.assigned:
        return AppColors.rideAssignedBorder;
      case RideStatus.inProgress:
        return AppColors.rideInProgressBorder;
      case RideStatus.completed:
        return AppColors.rideCompletedBorder;
      case RideStatus.cancelled:
        return AppColors.rideCancelledBorder;
    }
  }

  /// Get text color for status containers (high contrast)
  static Color getStatusTextColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequestedText;
      case RideStatus.assigned:
        return AppColors.rideAssignedText;
      case RideStatus.inProgress:
        return AppColors.rideInProgressText;
      case RideStatus.completed:
        return AppColors.rideCompletedText;
      case RideStatus.cancelled:
        return AppColors.rideCancelledText;
    }
  }

  /// Get appropriate icon for each status
  static IconData getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Icons.access_time; // clock icon
      case RideStatus.assigned:
        return Icons.person_pin; // person with location
      case RideStatus.inProgress:
        return Icons.local_taxi; // taxi icon instead of generic car
      case RideStatus.completed:
        return Icons.check_circle_outline; // outlined check for better visibility
      case RideStatus.cancelled:
        return Icons.highlight_off; // X icon instead of generic cancel
    }
  }

  /// Get status display name
  static String getStatusDisplayName(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'Requested';
      case RideStatus.assigned:
        return 'Assigned';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Create a consistent status badge widget
  static Widget createStatusBadge(RideStatus status, {
    double? fontSize,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusBackgroundColor(status),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getStatusBorderColor(status),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getStatusIcon(status),
            size: iconSize ?? 16,
            color: getStatusTextColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            getStatusDisplayName(status),
            style: TextStyle(
              color: getStatusTextColor(status),
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 12,
            ),
          ),
        ],
      ),
    );
  }
}
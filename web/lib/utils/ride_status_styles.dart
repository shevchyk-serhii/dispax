import 'package:flutter/material.dart';
import '../modules/ride_management/models/ride.dart';
import '../constants/app_colors.dart';

/// Utility class for ride status styling and presentation
class RideStatusStyles {
  RideStatusStyles._();

  /// Gets the primary color for the given ride status
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

  /// Gets the background color for the given ride status
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

  /// Gets the border color for the given ride status
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

  /// Gets the text color for the given ride status
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

  /// Gets the icon for the given ride status
  static IconData getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Icons.access_time;
      case RideStatus.assigned:
        return Icons.person_pin;
      case RideStatus.inProgress:
        return Icons.local_taxi;
      case RideStatus.completed:
        return Icons.check_circle_outline;
      case RideStatus.cancelled:
        return Icons.highlight_off;
    }
  }

  /// Gets the display name for the given ride status
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

  /// Creates a status badge widget for the given ride status
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
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
      case RideStatus.confirmed:
        return AppColors.success;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
      case RideStatus.handedOff:
        return AppColors.rideHandedOff;
    }
  }

  /// Gets the ride status color as a 32-bit ARGB integer.
  ///
  /// Mapbox annotations (`CircleAnnotationOptions.circleColor`) take a raw int
  /// rather than a Flutter [Color], so this exposes the same status palette in
  /// the form the map layer needs — keeping `RideStatusStyles` the single
  /// source of truth for status colors.
  static int getStatusColorValue(RideStatus status) =>
      getStatusColor(status).toARGB32();

  /// Gets the background color for the given ride status.
  ///
  /// Pass [brightness] (typically `Theme.of(context).brightness`) so the badge
  /// fill follows the active theme; the soft light tints become deep tinted
  /// surfaces in dark mode.
  static Color getStatusBackgroundColor(
    RideStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case RideStatus.requested:
        return isDark
            ? AppColors.rideRequestedBgDark
            : AppColors.rideRequestedBg;
      case RideStatus.assigned:
        return isDark ? AppColors.rideAssignedBgDark : AppColors.rideAssignedBg;
      case RideStatus.confirmed:
        return isDark ? AppColors.rideCompletedBgDark : AppColors.successBg;
      case RideStatus.inProgress:
        return isDark
            ? AppColors.rideInProgressBgDark
            : AppColors.rideInProgressBg;
      case RideStatus.completed:
        return isDark
            ? AppColors.rideCompletedBgDark
            : AppColors.rideCompletedBg;
      case RideStatus.cancelled:
        return isDark
            ? AppColors.rideCancelledBgDark
            : AppColors.rideCancelledBg;
      case RideStatus.handedOff:
        return isDark
            ? AppColors.rideHandedOffBgDark
            : AppColors.rideHandedOffBg;
    }
  }

  /// Gets the border color for the given ride status.
  ///
  /// In dark mode the saturated status color (used for icon/text) doubles as a
  /// subtle outline, so the badge edge stays legible against the dark fill.
  static Color getStatusBorderColor(
    RideStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    if (brightness == Brightness.dark) {
      return getStatusTextColor(
        status,
        brightness: brightness,
      ).withValues(alpha: 0.4);
    }
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequestedBorder;
      case RideStatus.assigned:
        return AppColors.rideAssignedBorder;
      case RideStatus.confirmed:
        return AppColors.successBorder;
      case RideStatus.inProgress:
        return AppColors.rideInProgressBorder;
      case RideStatus.completed:
        return AppColors.rideCompletedBorder;
      case RideStatus.cancelled:
        return AppColors.rideCancelledBorder;
      case RideStatus.handedOff:
        return AppColors.rideHandedOffBorder;
    }
  }

  /// Gets the text color for the given ride status.
  ///
  /// Pass [brightness] so the label/icon use the lighter dark-mode variants,
  /// which keep contrast against the deep tinted background.
  static Color getStatusTextColor(
    RideStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case RideStatus.requested:
        return isDark
            ? AppColors.rideRequestedTextDark
            : AppColors.rideRequestedText;
      case RideStatus.assigned:
        return isDark
            ? AppColors.rideAssignedTextDark
            : AppColors.rideAssignedText;
      case RideStatus.confirmed:
        return isDark
            ? AppColors.rideCompletedTextDark
            : AppColors.successStrong;
      case RideStatus.inProgress:
        return isDark
            ? AppColors.rideInProgressTextDark
            : AppColors.rideInProgressText;
      case RideStatus.completed:
        return isDark
            ? AppColors.rideCompletedTextDark
            : AppColors.rideCompletedText;
      case RideStatus.cancelled:
        return isDark
            ? AppColors.rideCancelledTextDark
            : AppColors.rideCancelledText;
      case RideStatus.handedOff:
        return isDark
            ? AppColors.rideHandedOffTextDark
            : AppColors.rideHandedOffText;
    }
  }

  /// Gets the icon for the given ride status
  static IconData getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Icons.access_time;
      case RideStatus.assigned:
        return Icons.person_pin;
      case RideStatus.confirmed:
        return Icons.check_circle;
      case RideStatus.inProgress:
        return Icons.local_taxi;
      case RideStatus.completed:
        return Icons.check_circle_outline;
      case RideStatus.cancelled:
        return Icons.highlight_off;
      case RideStatus.handedOff:
        return Icons.swap_horiz;
    }
  }

  /// Gets the display name for the given ride status.
  ///
  /// Pass [l10n] to get the localized label; when omitted the English fallback
  /// is returned (for callers without a [BuildContext]).
  static String getStatusDisplayName(
    RideStatus status, [
    AppLocalizations? l10n,
  ]) {
    if (l10n != null) {
      switch (status) {
        case RideStatus.requested:
          return l10n.requestedLabel;
        case RideStatus.assigned:
          return l10n.assignedLabel;
        case RideStatus.confirmed:
          return l10n.statusConfirmed;
        case RideStatus.inProgress:
          return l10n.inProgressLabel;
        case RideStatus.completed:
          return l10n.completed;
        case RideStatus.cancelled:
          return l10n.cancelled;
        case RideStatus.handedOff:
          return l10n.rideStatusHandedOff;
      }
    }
    switch (status) {
      case RideStatus.requested:
        return 'Requested';
      case RideStatus.assigned:
        return 'Assigned';
      case RideStatus.confirmed:
        return 'Confirmed';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
      case RideStatus.handedOff:
        return 'Handed Off';
    }
  }

  /// Gets the uppercase label for the given ride status.
  static String getStatusLabel(RideStatus status, [AppLocalizations? l10n]) =>
      getStatusDisplayName(status, l10n).toUpperCase();

  /// Creates a status badge widget for the given ride status.
  ///
  /// Pass [context] so the badge picks up the active theme brightness and
  /// renders correctly in dark mode; without it the badge falls back to the
  /// light palette.
  static Widget createStatusBadge(
    RideStatus status, {
    BuildContext? context,
    double? fontSize,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    final brightness = context != null
        ? Theme.of(context).brightness
        : Brightness.light;
    final l10n = context != null ? AppLocalizations.of(context) : null;
    final textColor = getStatusTextColor(status, brightness: brightness);
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusBackgroundColor(status, brightness: brightness),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getStatusBorderColor(status, brightness: brightness),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getStatusIcon(status), size: iconSize ?? 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            getStatusDisplayName(status, l10n),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 12,
            ),
          ),
        ],
      ),
    );
  }
}

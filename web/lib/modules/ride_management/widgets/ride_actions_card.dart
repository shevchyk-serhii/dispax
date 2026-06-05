import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';

class RideActionsCard extends StatelessWidget {
  final Ride ride;
  final bool isClientView;
  final VoidCallback? onEditRide;
  final VoidCallback? onCancelRide;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onShareRide;

  const RideActionsCard({
    super.key,
    required this.ride,
    this.isClientView = false,
    this.onEditRide,
    this.onCancelRide,
    this.onStartRide,
    this.onCompleteRide,
    this.onAssignDriver,
    this.onViewOnMap,
    this.onShareRide,
  });

  @override
  Widget build(BuildContext context) {
    final primaryAction = _getPrimaryAction();
    final secondaryActions = _getSecondaryActions();
    final dangerAction = _getDangerAction();

    if (primaryAction == null && secondaryActions.isEmpty && dangerAction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMd,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Secondary actions (equal-width tiles)
          if (secondaryActions.isNotEmpty) ...[
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < secondaryActions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: secondaryActions[i]),
                  ],
                ],
              ),
            ),
            if (primaryAction != null || dangerAction != null)
              const SizedBox(height: 10),
          ],

          // Primary CTA
          if (primaryAction != null) ...[
            primaryAction,
            if (dangerAction != null) const SizedBox(height: 8),
          ],

          // Danger action (subtle, below primary)
          if (dangerAction != null) dangerAction,
        ],
      ),
    );
  }

  Widget? _getPrimaryAction() {
    switch (ride.status) {
      case RideStatus.inProgress:
        if (!isClientView && onCompleteRide != null) {
          return _buildPrimaryButton(
            icon: Icons.check_circle_rounded,
            label: 'Complete Ride',
            onPressed: onCompleteRide!,
            color: AppColors.success,
          );
        }
      case RideStatus.assigned:
        if (!isClientView && onStartRide != null) {
          return _buildPrimaryButton(
            icon: Icons.play_circle_rounded,
            label: 'Start Ride',
            onPressed: onStartRide!,
            color: AppColors.accent,
          );
        }
      case RideStatus.requested:
        if (!isClientView && onAssignDriver != null) {
          return _buildPrimaryButton(
            icon: Icons.person_add_rounded,
            label: 'Assign Driver',
            onPressed: onAssignDriver!,
            color: AppColors.primary,
          );
        }
      default:
        break;
    }
    return null;
  }

  List<Widget> _getSecondaryActions() {
    final List<Widget> actions = [];

    if (onViewOnMap != null) {
      actions.add(_buildSecondaryButton(
        icon: Icons.map_outlined,
        label: 'View on Map',
        onPressed: onViewOnMap!,
      ));
    }

    if (onShareRide != null) {
      actions.add(_buildSecondaryButton(
        icon: Icons.ios_share_rounded,
        label: 'Share',
        onPressed: onShareRide!,
      ));
    }

    if (onEditRide != null &&
        (ride.status == RideStatus.requested || ride.status == RideStatus.assigned)) {
      actions.add(_buildSecondaryButton(
        icon: Icons.edit_outlined,
        label: 'Edit',
        onPressed: onEditRide!,
      ));
    }

    return actions;
  }

  Widget? _getDangerAction() {
    if (onCancelRide != null &&
        (ride.status == RideStatus.requested || ride.status == RideStatus.assigned)) {
      return _buildDangerButton(
        icon: Icons.cancel_outlined,
        label: 'Cancel Ride',
        onPressed: onCancelRide!,
      );
    }
    return null;
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: AppStyles.labelLarge),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: AppColors.error.withAlpha(160)),
      label: Text(
        label,
        style: AppStyles.labelMedium.copyWith(
          color: AppColors.error.withAlpha(160),
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }
}

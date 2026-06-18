import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/lucide_compat.dart';

/// Data class holding information about an at-risk ETA.
class EtaAtRiskInfo {
  final String rideId;
  final String driverName;
  final int etaMinutes;
  final int pickupInMinutes;
  final int slackMinutes;

  const EtaAtRiskInfo({
    required this.rideId,
    required this.driverName,
    required this.etaMinutes,
    required this.pickupInMinutes,
    required this.slackMinutes,
  });
}

/// A dismissible alert card displayed at the top of the PendingRidesPanel
/// when a driver's ETA is at risk (i.e. slackMinutes is negative).
class EtaAlertCard extends StatelessWidget {
  final EtaAtRiskInfo info;
  final VoidCallback? onDismiss;
  final VoidCallback? onReassign;
  final VoidCallback? onView;

  const EtaAlertCard({
    super.key,
    required this.info,
    this.onDismiss,
    this.onReassign,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgAlpha = isDark ? 0.12 : 0.06;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border(left: BorderSide(color: AppColors.error, width: 4)),
        boxShadow: AppStyles.glassCardDecoration.boxShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                LucideCompat.alertTriangle,
                color: AppColors.error,
                size: AppDimensions.iconMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.driverName, style: AppStyles.labelLarge),
                  Text(
                    'ETA ${info.etaMinutes}min · Pickup in ${info.pickupInMinutes}min'
                    ' · Slack ${info.slackMinutes}min',
                    style: AppStyles.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (onReassign != null)
                        TextButton(
                          onPressed: onReassign,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Reassign'),
                        ),
                      if (onReassign != null && onView != null)
                        const SizedBox(width: AppDimensions.paddingSmall),
                      if (onView != null)
                        TextButton(
                          onPressed: onView,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(LucideCompat.x),
                color: AppColors.textSecondary,
                iconSize: AppDimensions.iconSmall,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

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

/// A dismissible alert card displayed in the dispatcher split-view when a
/// driver's ETA is at risk (i.e. slackMinutes is negative).
///
/// Pixel spec: white card, uniform border #FCA5A5 + left-accent 4px #EF4444
/// rendered via Stack, radius14, pad18/20; icon box 42px #FEF2F2;
/// title 15px w700 #991B1B + badge 10px uppercase; 3 stat tiles (Driver ETA
/// / Pickup in / Slack — Slack tile red).
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorBorder),
        boxShadow: AppStyles.cardDecoration.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar 4px #EF4444
              Container(width: 4, color: AppColors.error),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Warning icon box 42×42 #FEF2F2
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideCompat.alertTriangle,
                              color: AppColors.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Ride at risk of delay',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.errorStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PREDICTIVE ETA MONITOR · 60S',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Driver name subtitle
                                Text(
                                  info.driverName,
                                  style: AppStyles.bodySmall,
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
                      // ── Summary line (preserved for test selectors) ───
                      const SizedBox(height: 8),
                      Text(
                        'ETA ${info.etaMinutes}min · Pickup in ${info.pickupInMinutes}min'
                        ' · Slack ${info.slackMinutes}min',
                        style: AppStyles.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      // ── Stat tiles row ────────────────────────────────
                      Row(
                        children: [
                          _StatTile(
                            label: 'DRIVER ETA',
                            value: '${info.etaMinutes}min',
                            isRed: false,
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            label: 'PICKUP IN',
                            value: '${info.pickupInMinutes}min',
                            isRed: false,
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            label: 'SLACK',
                            value: '${info.slackMinutes}min',
                            isRed: true,
                          ),
                        ],
                      ),
                      // ── Action buttons ────────────────────────────────
                      if (onReassign != null || onView != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (onReassign != null)
                              SizedBox(
                                height: 34,
                                child: FilledButton(
                                  onPressed: onReassign,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Reassign'),
                                ),
                              ),
                            if (onReassign != null && onView != null)
                              const SizedBox(width: 8),
                            if (onView != null)
                              SizedBox(
                                height: 34,
                                child: OutlinedButton(
                                  onPressed: onView,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(
                                      color: AppColors.borderSecondary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('View'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact stat tile used inside [EtaAlertCard].
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isRed;

  const _StatTile({
    required this.label,
    required this.value,
    required this.isRed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isRed
        ? AppColors.errorBg
        : colorScheme.surfaceContainerHighest;
    final borderColor = isRed
        ? AppColors.errorBorder
        : colorScheme.outlineVariant;
    final valueColor = isRed ? AppColors.error : colorScheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

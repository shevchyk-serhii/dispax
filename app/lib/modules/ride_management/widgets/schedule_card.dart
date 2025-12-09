import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';

class ScheduleCard extends StatelessWidget {
  final DateTime pickupDateTime;
  final VoidCallback onSelectDateTime;

  const ScheduleCard({
    Key? key,
    required this.pickupDateTime,
    required this.onSelectDateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppColors.secretaryColor, size: AppDimensions.iconLarge),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  'Schedule',
                  style: AppStyles.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            InkWell(
              onTap: onSelectDateTime,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textSecondary),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Date & Time *',
                            style: AppStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppDimensions.paddingXSmall),
                          Text(
                            DateFormat('MMM dd, yyyy - HH:mm').format(pickupDateTime),
                            style: AppStyles.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';
import '../../core/date_utils.dart';

class FlightInfoCard extends StatelessWidget {
  final Ride ride;

  const FlightInfoCard({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight_land,
                color: Theme.of(context).colorScheme.primary,
                size: AppDimensions.iconLarge,
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flight ${ride.flightNumber ?? 'N/A'}',
                      style: AppStyles.titleLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    Text(
                      'Terminal ${ride.terminal ?? 'N/A'} • Gate ${ride.gate ?? 'N/A'}',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(150),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(100),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Scheduled pickup:',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        AppDateUtils.formatDateTime(ride.pickupDateTime),
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.paddingSmall),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Driver:',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ride.driverName ?? 'Not assigned',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class FlightActionButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onConfirmArrival;
  final VoidCallback onDelayPickup;

  const FlightActionButtons({
    super.key,
    required this.isLoading,
    required this.onConfirmArrival,
    required this.onDelayPickup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: isLoading ? null : onConfirmArrival,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingLarge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    Text(
                      'Confirm Arrival',
                      style: AppStyles.labelLarge.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: AppDimensions.paddingMedium),

        OutlinedButton(
          onPressed: isLoading ? null : onDelayPickup,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
            side: BorderSide(
              color: AppColors.textOnPrimary.withAlpha(100),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingLarge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Delay Pickup',
                style: AppStyles.labelLarge.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
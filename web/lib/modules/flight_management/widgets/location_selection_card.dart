import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';
import 'location_option_item.dart';

class LocationSelectionCard extends StatelessWidget {
  final String selectedLocation;
  final TextEditingController customLocationController;
  final ValueChanged<String> onLocationSelected;
  final List<String> locationOptions;

  const LocationSelectionCard({
    super.key,
    required this.selectedLocation,
    required this.customLocationController,
    required this.onLocationSelected,
    required this.locationOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where are you now?',
            style: AppStyles.titleMedium.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          Text(
            'Select your current location so the driver can easily find you',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textOnPrimary.withAlpha(180),
            ),
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          ...locationOptions.map((location) => LocationOptionItem(
            location: location,
            isSelected: selectedLocation == location,
            onTap: () => onLocationSelected(location),
          )),

          if (selectedLocation == 'Other location (specify below)') ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            TextField(
              controller: customLocationController,
              decoration: InputDecoration(
                hintText: 'Specify your location',
                filled: true,
                fillColor: AppColors.surface.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                hintStyle: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textOnPrimary.withAlpha(128),
                ),
              ),
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.textOnPrimary,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}
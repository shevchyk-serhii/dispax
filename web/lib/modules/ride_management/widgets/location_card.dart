import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';

class LocationCard extends StatelessWidget {
  final TextEditingController fromAddressController;
  final TextEditingController toAddressController;
  final VoidCallback? onFromAddressChanged;
  final VoidCallback? onToAddressChanged;

  const LocationCard({
    Key? key,
    required this.fromAddressController,
    required this.toAddressController,
    this.onFromAddressChanged,
    this.onToAddressChanged,
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
                Icon(Icons.location_on, color: AppColors.secretaryColor, size: AppDimensions.iconLarge),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  'Route Information',
                  style: AppStyles.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: fromAddressController,
              decoration: InputDecoration(
                labelText: 'Pickup Address *',
                hintText: 'Enter pickup location',
                prefixIcon: Icon(Icons.trip_origin, color: AppColors.secretaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pickup address is required';
                }
                return null;
              },
              onChanged: (value) => onFromAddressChanged?.call(),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: toAddressController,
              decoration: InputDecoration(
                labelText: 'Destination Address *',
                hintText: 'Enter destination location',
                prefixIcon: Icon(Icons.location_on, color: AppColors.secretaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Destination address is required';
                }
                return null;
              },
              onChanged: (value) => onToAddressChanged?.call(),
            ),
          ],
        ),
      ),
    );
  }
}
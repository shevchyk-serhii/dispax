import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

class LocationCard extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final ValueChanged<String> onFromAddressChanged;
  final ValueChanged<String> onToAddressChanged;

  const LocationCard({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.onFromAddressChanged,
    required this.onToAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.successStrong,
                  size: 24,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Ride Locations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              initialValue: fromAddress,
              decoration: InputDecoration(
                labelText: 'From',
                hintText: 'Pick-up location',
                prefixIcon: Icon(
                  Icons.trip_origin,
                  color: AppColors.secretaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pick-up location is required';
                }
                return null;
              },
              onChanged: onFromAddressChanged,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              initialValue: toAddress,
              decoration: InputDecoration(
                labelText: 'To',
                hintText: 'Drop-off location',
                prefixIcon: Icon(
                  Icons.location_on,
                  color: AppColors.secretaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Drop-off location is required';
                }
                return null;
              },
              onChanged: onToAddressChanged,
            ),
          ],
        ),
      ),
    );
  }
}

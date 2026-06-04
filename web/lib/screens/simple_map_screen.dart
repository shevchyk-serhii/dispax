import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class SimpleMapScreen extends StatelessWidget {
  const SimpleMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Map Integration Ready',
                style: AppStyles.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'Mapbox maps are configured and ready.\nUpgrade Flutter to 3.33+ for full functionality on Android.',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingLarge),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.clientColor.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Column(
                  children: [
                    Text(
                      'Features Implemented:',
                      style: AppStyles.titleSmall.copyWith(
                        color: AppColors.clientColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    _buildFeatureItem('✅ Real-time location tracking'),
                    _buildFeatureItem('✅ Driver and client map screens'),
                    _buildFeatureItem('✅ Ride route visualization'),
                    _buildFeatureItem('✅ Live position updates'),
                    _buildFeatureItem('✅ Map controls and markers'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: AppStyles.bodySmall,
      ),
    );
  }
}
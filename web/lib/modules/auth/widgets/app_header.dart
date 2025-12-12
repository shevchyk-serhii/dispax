import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: AppDimensions.iconHero,
          height: AppDimensions.iconHero,
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXXLarge),
            border: Border.all(color: AppColors.glassBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXXLarge),
            child: Image.asset(
              'assets/oktopus_icon.png',
              width: AppDimensions.iconLogo,
              height: AppDimensions.iconLogo,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),
        Text(
          'Der Oktopus',
          style: AppStyles.glassHeadlineLarge,
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          'Smart Mobility Solutions',
          style: AppStyles.glassBodyLarge,
        ),
      ],
    );
  }
}
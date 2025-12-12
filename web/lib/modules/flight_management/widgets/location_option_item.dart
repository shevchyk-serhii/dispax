import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class LocationOptionItem extends StatelessWidget {
  final String location;
  final bool isSelected;
  final VoidCallback onTap;

  const LocationOptionItem({
    Key? key,
    required this.location,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.clientColor.withAlpha(100)
                : AppColors.surface.withAlpha(50),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isSelected 
                  ? AppColors.clientColor
                  : AppColors.textOnPrimary.withAlpha(50),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected 
                    ? AppColors.clientColor 
                    : AppColors.textOnPrimary.withAlpha(128),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Text(
                  location,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
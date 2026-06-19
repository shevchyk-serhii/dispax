import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class LocationOptionItem extends StatelessWidget {
  final String location;
  final bool isSelected;
  final VoidCallback onTap;

  const LocationOptionItem({
    super.key,
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

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
            // Card parent is graphite (AppColors.primary), so the selected
            // state uses the sky accent and unselected uses a white overlay —
            // graphite-on-graphite would be invisible.
            color: isSelected
                ? AppColors.accent.withAlpha(60)
                : Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentLight
                  : AppColors.textOnPrimary.withAlpha(50),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.accentLight
                    : AppColors.textOnPrimary.withAlpha(128),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Text(
                  location,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
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

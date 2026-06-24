import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: AppDimensions.iconHero,
          height: AppDimensions.iconHero,
          decoration: BoxDecoration(
            color: AppColors.onDarkBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXXLarge),
            border: Border.all(color: AppColors.onDarkBorder, width: 2),
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
              'assets/dispax_icon.png',
              width: AppDimensions.iconLogo,
              height: AppDimensions.iconLogo,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),
        Text(l10n.appTitle, style: AppStyles.onDarkHeadlineLarge),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(l10n.appSubtitle, style: AppStyles.onDarkBodyLarge),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../widgets/widgets.dart';

class TestCredentialsSection extends StatelessWidget {
  final Function(String email, String password) onCredentialTap;
  final Function(String email) onQuickLogin;

  const TestCredentialsSection({
    super.key,
    required this.onCredentialTap,
    required this.onQuickLogin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          'Quick Access for Testing',
          style: AppStyles.titleMedium.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingMedium),

        TestCredentialsCard(onCredentialTap: onCredentialTap),

        const SizedBox(height: AppDimensions.paddingMedium),

        QuickLoginButtons(onQuickLogin: onQuickLogin),
      ],
    );
  }
}

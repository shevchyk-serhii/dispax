import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Quick-login role buttons for the dev/testing section on the sign-in screen.
///
/// The section now sits on a light surface (login redesign) so tokens follow
/// the app's textPrimary / borderPrimary ramp rather than the former
/// white-on-dark glass style.
class QuickLoginButtons extends StatelessWidget {
  final Function(String email) onQuickLogin;

  const QuickLoginButtons({super.key, required this.onQuickLogin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _buildButton(context, 'Client', 'client1@bmw.de', Icons.person, isDark),
        _buildButton(
          context,
          'Driver',
          'driver1@dispax.de',
          Icons.drive_eta,
          isDark,
        ),
        _buildButton(
          context,
          'Secretary',
          'secretary@dispax.de',
          Icons.business_center,
          isDark,
        ),
        _buildButton(
          context,
          'Dispatcher',
          'dispatcher@dispax.de',
          Icons.dashboard,
          isDark,
        ),
        _buildButton(
          context,
          'SuperAdmin',
          'superadmin@dispax.de',
          Icons.admin_panel_settings,
          isDark,
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context,
    String role,
    String email,
    IconData icon,
    bool isDark,
  ) {
    final borderColor = isDark
        ? AppColors.borderSecondaryDark
        : AppColors.borderSecondary;
    final bgColor = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.surfaceVariant;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final iconColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onQuickLogin(email),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Collapsible card listing test credentials.
///
/// Now renders on a light/surface background (login redesign) — text and
/// border tokens follow the app's borderPrimary / textPrimary ramp instead
/// of the former white-on-dark glass style.
class TestCredentialsCard extends StatelessWidget {
  final Function(String email, String password) onCredentialTap;

  const TestCredentialsCard({super.key, required this.onCredentialTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
    final border = isDark
        ? AppColors.borderSecondaryDark
        : AppColors.borderPrimary;
    final titleColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final emailColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final iconColor = isDark ? AppColors.textLightDark : AppColors.textLight;
    final passwordBg = isDark ? AppColors.borderDark : AppColors.borderPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Accounts',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: titleColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            buildCredentialRow(
              'Client',
              'client1@bmw.de',
              Icons.person,
              titleColor,
              emailColor,
              iconColor,
            ),
            buildCredentialRow(
              'Driver',
              'driver1@dispax.de',
              Icons.drive_eta,
              titleColor,
              emailColor,
              iconColor,
            ),
            buildCredentialRow(
              'Secretary',
              'secretary@dispax.de',
              Icons.business_center,
              titleColor,
              emailColor,
              iconColor,
            ),
            buildCredentialRow(
              'Dispatcher',
              'dispatcher@dispax.de',
              Icons.dashboard,
              titleColor,
              emailColor,
              iconColor,
            ),
            buildCredentialRow(
              'SuperAdmin',
              'superadmin@dispax.de',
              Icons.admin_panel_settings,
              titleColor,
              emailColor,
              iconColor,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: passwordBg.withValues(alpha: isDark ? 0.3 : 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Password for all: password123',
                style: TextStyle(
                  fontSize: 12,
                  color: emailColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCredentialRow(
    String role,
    String email,
    IconData icon,
    Color titleColor,
    Color emailColor,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => onCredentialTap(email, 'password123'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(fontSize: 11, color: emailColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.touch_app, size: 13, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

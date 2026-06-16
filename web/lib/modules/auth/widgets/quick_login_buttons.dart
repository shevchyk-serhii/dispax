import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class QuickLoginButtons extends StatelessWidget {
  final Function(String email) onQuickLogin;

  const QuickLoginButtons({super.key, required this.onQuickLogin});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildButton(
          'Client',
          'client1@bmw.de',
          Icons.person,
          AppColors.clientColor,
        ),
        _buildButton(
          'Driver',
          'driver1@dispax.de',
          Icons.drive_eta,
          AppColors.driverColor,
        ),
        _buildButton(
          'Secretary',
          'secretary@dispax.de',
          Icons.business_center,
          AppColors.secretaryColor,
        ),
        _buildButton(
          'Dispatcher',
          'dispatcher@dispax.de',
          Icons.dashboard,
          AppColors.dispatcherColor,
        ),
        _buildButton(
          'SuperAdmin',
          'superadmin@dispax.de',
          Icons.admin_panel_settings,
          AppColors.superAdminColor,
        ),
      ],
    );
  }

  Widget _buildButton(String role, String email, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onQuickLogin(email),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The login screen sits on a fixed dark gradient (the label is
                // hardcoded white), and the role colors are graphite — drawing
                // the icon in `color` made it invisible. Match the label.
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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

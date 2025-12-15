import 'package:flutter/material.dart';

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
        _buildQuickLoginButton(
          'Driver',
          'john.driver@oktopus.com',
          Icons.drive_eta,
          Colors.blue
        ),
        _buildQuickLoginButton(
          'Client',
          'anna.client@example.com',
          Icons.person,
          Colors.green
        ),
        _buildQuickLoginButton(
          'Secretary',
          'maria.secretary@oktopus.com',
          Icons.business_center,
          Colors.purple
        ),
        _buildQuickLoginButton(
          'Dispatcher',
          'peter.dispatcher@oktopus.com',
          Icons.dashboard,
          Colors.orange
        ),
      ],
    );
  }

  Widget _buildQuickLoginButton(
    String role,
    String email,
    IconData icon,
    MaterialColor color
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color[400]!,
            color[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color[300]!.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
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

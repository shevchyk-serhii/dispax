import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../../constants/app_colors.dart';

class UserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Person user;
  final VoidCallback onLogout;
  final VoidCallback onProfile;

  const UserAppBar({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.local_taxi, size: 32),
          const SizedBox(width: 12),
          Text(getAppBarTitle(user.role)),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'profile':
                onProfile();
                break;
              case 'logout':
                onLogout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 8),
                  Text(user.name),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.name.split(' ').map((e) => e[0]).take(2).join(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String getAppBarTitle(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return 'Driver Dashboard';
      case PersonRole.client:
        return 'My Rides';
      case PersonRole.secretary:
      case PersonRole.clientSecretary:
        return 'Secretary Dashboard';
      case PersonRole.dispatcher:
        return 'Dispatcher Dashboard';
      case PersonRole.admin:
        return 'Admin Dashboard';
      case PersonRole.superAdmin:
        return 'Platform Admin';
    }
  }
}

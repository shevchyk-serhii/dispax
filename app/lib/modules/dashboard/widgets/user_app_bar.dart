import 'package:flutter/material.dart';
import '../../core/models/person.dart';

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
      title: Text(getAppBarTitle(user.role)),
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
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              child: Text(
                user.name.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(fontSize: 12),
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
        return 'Secretary Dashboard';
      case PersonRole.dispatcher:
        return 'Dispatcher Dashboard';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/person.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.local_taxi, size: 32),
          const SizedBox(width: 12),
          Text(getAppBarTitle(l10n, user.role)),
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
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    l10n.logout,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AvatarCircle(
              user: user,
              apiClient: context.read<AuthBloc>().apiClient,
              radius: 16,
            ),
          ),
        ),
      ],
    );
  }

  String getAppBarTitle(AppLocalizations l10n, PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return l10n.driverDashboardTitle;
      case PersonRole.client:
        return l10n.myRides;
      case PersonRole.secretary:
      case PersonRole.clientSecretary:
        return l10n.secretaryDashboardTitle;
      case PersonRole.dispatcher:
        return l10n.dispatcherDashboardTitle;
      case PersonRole.admin:
        return l10n.adminDashboardTitle;
      case PersonRole.superAdmin:
        return l10n.platformAdminTitle;
    }
  }
}

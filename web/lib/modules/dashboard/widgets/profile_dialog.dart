import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/person.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';

class ProfileDialog extends StatelessWidget {
  final Person user;

  const ProfileDialog({super.key, required this.user});

  static void show(BuildContext context, Person user) {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return AlertDialog(
          title: const Text('Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildProfileRow('Name', user.name),
              buildProfileRow('Email', user.email),
              buildProfileRow('Role', getRoleDisplayName(user.role)),
              if (user.companyId != null)
                buildProfileRow('Company', 'ID: ${user.companyId}'),
              if (user.licenseNumber != null)
                buildProfileRow('License', user.licenseNumber!),
              if (user.phone != null) buildProfileRow('Phone', user.phone!),

              if (authState.biometricAvailable) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Настройки безопасности',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Вход по биометрии',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    Switch(
                      value: authState.biometricEnabled,
                      onChanged: (value) {
                        context.read<AuthBloc>().add(
                          AuthBiometricSetupRequested(
                            enabled: value,
                            userId: user.id.toString(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  authState.biometricEnabled
                    ? 'Быстрый вход с Face ID/Touch ID включен'
                    : 'Используйте биометрию для быстрого входа',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String getRoleDisplayName(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return 'Driver';
      case PersonRole.client:
        return 'Client';
      case PersonRole.secretary:
        return 'Secretary';
      case PersonRole.dispatcher:
        return 'Dispatcher';
    }
  }
}

import 'package:flutter/material.dart';
import '../../models/person.dart';

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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
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

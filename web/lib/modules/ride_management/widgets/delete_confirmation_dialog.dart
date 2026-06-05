import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final Ride ride;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.ride,
    required this.onConfirm,
  });

  static void show(BuildContext context, Ride ride, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) =>
          DeleteConfirmationDialog(ride: ride, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmation'),
      content: Text('Delete ride ${ride.from} → ${ride.to}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
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
    showAdaptiveDialog(
      context: context,
      builder: (context) =>
          DeleteConfirmationDialog(ride: ride, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.deleteConfirmationTitle),
      content: Text(
        l10n.deleteRideConfirmMessage(ride.from.address, ride.to.address),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: Text(
            l10n.delete,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

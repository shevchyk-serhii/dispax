import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
import '../../core/date_utils.dart';
import '../../../constants/app_colors.dart';

class RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RideCard({
    super.key,
    required this.ride,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.directions_car),
        title: Text('${ride.from} → ${ride.to}'),
        subtitle: Text(
          l10n.rideCardTimeLabel(
            AppDateUtils.getRelativeDateString(ride.pickupDateTime),
          ),
        ),
        trailing: buildActions(context),
        onTap: onTap,
      ),
    );
  }

  Widget? buildActions(BuildContext context) {
    if (onEdit == null && onDelete == null) return null;

    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.editAction),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: Text(
                l10n.delete,
                style: const TextStyle(color: AppColors.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

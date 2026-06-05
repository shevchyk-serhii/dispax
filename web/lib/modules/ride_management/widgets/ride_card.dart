import 'package:flutter/material.dart';
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.directions_car),
        title: Text('${ride.from} → ${ride.to}'),
        subtitle: Text(
          'Time: ${AppDateUtils.getRelativeDateString(ride.pickupDateTime)}',
        ),
        trailing: buildActions(context),
        onTap: onTap,
      ),
    );
  }

  Widget? buildActions(BuildContext context) {
    if (onEdit == null && onDelete == null) return null;

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
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: Text('Delete', style: TextStyle(color: AppColors.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class RideActionsCard extends StatelessWidget {
  final Ride ride;
  final bool isClientView;
  final VoidCallback? onEditRide;
  final VoidCallback? onCancelRide;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onShareRide;

  const RideActionsCard({
    super.key,
    required this.ride,
    this.isClientView = false,
    this.onEditRide,
    this.onCancelRide,
    this.onStartRide,
    this.onCompleteRide,
    this.onAssignDriver,
    this.onViewOnMap,
    this.onShareRide,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _getAvailableActions();

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getAvailableActions() {
    final List<Widget> actions = [];

    if (onViewOnMap != null) {
      actions.add(_buildActionButton(
        icon: Icons.map,
        label: 'View on Map',
        onPressed: onViewOnMap!,
        color: AppColors.primary,
      ));
    }

    if (onShareRide != null) {
      actions.add(_buildActionButton(
        icon: Icons.share,
        label: 'Share Ride',
        onPressed: onShareRide!,
        color: Colors.blue,
      ));
    }

    switch (ride.status) {
      case RideStatus.requested:
        if (!isClientView && onAssignDriver != null) {
          actions.add(_buildActionButton(
            icon: Icons.person_add,
            label: 'Assign Driver',
            onPressed: onAssignDriver!,
            color: Colors.green,
          ));
        }

        if (onEditRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.edit,
            label: 'Edit Ride',
            onPressed: onEditRide!,
            color: Colors.orange,
          ));
        }

        if (onCancelRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.cancel,
            label: 'Cancel',
            onPressed: onCancelRide!,
            color: Colors.red,
          ));
        }
        break;

      case RideStatus.assigned:
        if (!isClientView && onStartRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.play_arrow,
            label: 'Start Ride',
            onPressed: onStartRide!,
            color: Colors.green,
            isPrimary: true,
          ));
        }

        if (onEditRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.edit,
            label: 'Edit Ride',
            onPressed: onEditRide!,
            color: Colors.orange,
          ));
        }

        if (onCancelRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.cancel,
            label: 'Cancel',
            onPressed: onCancelRide!,
            color: Colors.red,
          ));
        }
        break;

      case RideStatus.inProgress:
        if (!isClientView && onCompleteRide != null) {
          actions.add(_buildActionButton(
            icon: Icons.check_circle,
            label: 'Complete Ride',
            onPressed: onCompleteRide!,
            color: Colors.green,
            isPrimary: true,
          ));
        }
        break;

      case RideStatus.completed:
      case RideStatus.cancelled:

        break;
    }

    return actions;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isPrimary = false,
  }) {
    return isPrimary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: color),
            label: Text(label, style: TextStyle(color: color)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
  }
}
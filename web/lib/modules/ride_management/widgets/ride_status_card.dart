import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../utils/ride_status_styles.dart';

class RideStatusCard extends StatelessWidget {
  final Ride ride;
  final bool isClientView;

  const RideStatusCard({
    super.key,
    required this.ride,
    this.isClientView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  RideStatusStyles.getStatusIcon(ride.status),
                  color: RideStatusStyles.getStatusColor(ride.status),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${RideStatusStyles.getStatusDisplayName(ride.status)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: RideStatusStyles.getStatusColor(ride.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusDescription(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (ride.estimatedPrice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Price: ${ride.estimatedPrice!.toStringAsFixed(0)} UAH',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (ride.status) {
      case RideStatus.requested:
        return 'Waiting for driver assignment';
      case RideStatus.assigned:
        return isClientView
            ? 'Driver has been assigned and is on the way'
            : 'You have been assigned to this ride';
      case RideStatus.confirmed:
        return isClientView
            ? 'Driver confirmed your ride'
            : 'You confirmed this ride — ready to start';
      case RideStatus.inProgress:
        return isClientView
            ? 'Your ride is currently in progress'
            : 'Ride in progress - take care of your passenger';
      case RideStatus.completed:
        return 'Ride has been completed successfully';
      case RideStatus.cancelled:
        return 'This ride has been cancelled';
    }
  }
}

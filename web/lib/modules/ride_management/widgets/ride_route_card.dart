import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class RideRouteCard extends StatelessWidget {
  final Ride ride;

  const RideRouteCard({
    Key? key,
    required this.ride,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // From Location
            _buildLocationRow(
              context,
              icon: Icons.trip_origin,
              label: 'From',
              location: ride.pickupLocation,
              color: Colors.green,
            ),
            
            const SizedBox(height: 12),
            
            // To Location
            _buildLocationRow(
              context,
              icon: Icons.location_on,
              label: 'To',
              location: ride.dropoffLocation,
              color: Colors.red,
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Pickup Time
            Row(
              children: [
                Icon(Icons.schedule, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Time',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMM dd, yyyy \'at\' HH:mm').format(ride.pickupTime),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (ride.estimatedDistance != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.straighten, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${ride.estimatedDistance!.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            
            if (ride.estimatedDuration != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${ride.estimatedDuration} min',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String location,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                location,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
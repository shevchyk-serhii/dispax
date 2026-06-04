import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class RideFlightCard extends StatelessWidget {
  final Ride ride;

  const RideFlightCard({
    super.key,
    required this.ride,
  });

  @override
  Widget build(BuildContext context) {
    if (ride.flightInfo == null) {
      return const SizedBox.shrink();
    }

    final flight = ride.flightInfo!;

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
                  Icons.flight,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Flight Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildFlightInfoRow(
              context,
              icon: Icons.confirmation_number,
              label: 'Flight Number',
              value: flight.flightNumber,
            ),

            const SizedBox(height: 12),

            _buildFlightInfoRow(
              context,
              icon: Icons.schedule,
              label: flight.isArrival ? 'Arrival Time' : 'Departure Time',
              value: DateFormat('HH:mm, MMM dd').format(flight.flightTime),
            ),

            if (flight.terminal != null) ...[
              const SizedBox(height: 12),
              _buildFlightInfoRow(
                context,
                icon: Icons.business,
                label: 'Terminal',
                value: flight.terminal!,
              ),
            ],

            if (flight.gate != null) ...[
              const SizedBox(height: 12),
              _buildFlightInfoRow(
                context,
                icon: Icons.exit_to_app,
                label: 'Gate',
                value: flight.gate!,
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getFlightStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getFlightStatusColor().withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        flight.status,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getFlightStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (flight.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      flight.notes!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getFlightStatusColor() {
    final status = ride.flightInfo!.status.toLowerCase();
    if (status.contains('on time')) return Colors.green;
    if (status.contains('delayed')) return Colors.orange;
    if (status.contains('cancelled')) return Colors.red;
    if (status.contains('boarding')) return Colors.blue;
    if (status.contains('arrived')) return Colors.green[700]!;
    return AppColors.primary;
  }
}
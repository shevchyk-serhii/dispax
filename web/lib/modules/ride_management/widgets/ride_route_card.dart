import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../core/navigation_utils.dart';

class RideRouteCard extends StatelessWidget {
  final Ride ride;

  const RideRouteCard({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.routeInformationLabel,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildLocationRow(
              context,
              icon: Icons.trip_origin,
              label: l10n.fromLabel,
              location: ride.pickupLocation,
              color: AppColors.success,
            ),

            const SizedBox(height: 12),

            _buildLocationRow(
              context,
              icon: Icons.location_on,
              label: l10n.toLabel,
              location: ride.dropoffLocation,
              color: AppColors.error,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pickupTimeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'EEEE, MMM dd, yyyy \'at\' HH:mm',
                        ).format(ride.pickupTime),
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
                  Icon(
                    Icons.straighten,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.distanceLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  Icon(
                    Icons.timer,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.durationLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

            if (ride.etaMinutes != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.etaToClientLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '~${ride.etaMinutes} min',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    NavigationUtils.openGoogleMapsRoute(ride.from, ride.to),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(l10n.openInGoogleMapsButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                location,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

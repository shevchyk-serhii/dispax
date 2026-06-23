import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../ride_management/models/ride.dart';
import '../../../screens/ride_details_screen.dart';
import '../../core/widgets/ride_info_row.dart';
import 'ride_quick_actions.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';

class TodayRideCard extends StatelessWidget {
  final Ride ride;
  final bool isLast;
  final VoidCallback? onCallClient;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final int? approachingDistanceMeters;
  final int? etaMinutes;
  final VoidCallback? onViewDetails;

  const TodayRideCard({
    super.key,
    required this.ride,
    this.isLast = false,
    this.onCallClient,
    this.onStartRide,
    this.onCompleteRide,
    this.approachingDistanceMeters,
    this.etaMinutes,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = RideStatusStyles.getStatusColor(ride.status);
    final isUpcoming = ride.pickupDateTime.isAfter(DateTime.now());
    final timeUntilRide = ride.pickupDateTime.difference(DateTime.now());

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Card(
        elevation: 2,
        // clipBehavior rounds the child's corners so the inner Container's
        // non-uniform Border doesn't need its own borderRadius (which Flutter
        // forbids on borders with non-uniform side colors).
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            if (onViewDetails != null) {
              onViewDetails!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RideDetailsScreen(ride: ride),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: statusColor, width: 4),
                top: BorderSide(color: statusColor.withAlpha(40), width: 1),
                right: BorderSide(color: statusColor.withAlpha(40), width: 1),
                bottom: BorderSide(color: statusColor.withAlpha(40), width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(context, statusColor, isUpcoming, timeUntilRide),
                _buildContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color statusColor,
    bool isUpcoming,
    Duration timeUntilRide,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(18),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The chip group is wrapped in [Expanded] so it yields width to the
          // status pill instead of overflowing when all chips (Soon, distance,
          // ETA) are present on a narrow screen. Chip texts flex + ellipsis so
          // the row can never blow past the available space.
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat.Hm().format(ride.pickupDateTime),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isUpcoming && timeUntilRide.inHours < 2)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Soon',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (approachingDistanceMeters != null)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: approachingDistanceMeters! <= 100
                            ? AppColors.success
                            : approachingDistanceMeters! <= 500
                            ? AppColors.accent
                            : AppColors.info,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              approachingDistanceMeters! <= 100
                                  ? 'Arrived'
                                  : approachingDistanceMeters! < 1000
                                  ? '${approachingDistanceMeters}m'
                                  : '${(approachingDistanceMeters! / 1000).toStringAsFixed(1)}km',
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (etaMinutes != null && ride.status == RideStatus.inProgress)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '~$etaMinutes min',
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: AppStyles.labelLarge.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              RideStatusStyles.getStatusLabel(ride.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RideInfoRow(
            icon: Icons.person,
            text: ride.clientName,
            label: 'Client',
          ),
          const SizedBox(height: 12),
          RideInfoRow(
            icon: Icons.location_on,
            text: ride.from.address,
            label: 'Pickup',
          ),
          const SizedBox(height: 12),
          RideInfoRow(
            icon: Icons.flag,
            text: ride.to.address,
            label: 'Destination',
          ),
          if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty) ...[
            const SizedBox(height: 12),
            RideInfoRow(
              icon: Icons.flight,
              text: ride.fullFlightInfo,
              label: 'Flight',
            ),
          ],
          const SizedBox(height: 16),
          RideQuickActions(
            ride: ride,
            onCallClient: onCallClient,
            onStartRide: onStartRide,
            onCompleteRide: onCompleteRide,
            onViewDetails:
                onViewDetails ??
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RideDetailsScreen(ride: ride),
                    ),
                  );
                },
          ),
        ],
      ),
    );
  }
}

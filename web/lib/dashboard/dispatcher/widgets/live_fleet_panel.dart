import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../modules/ride_management/models/ride.dart';

/// Status of a driver in the live fleet view.
enum _FleetDriverStatus { onTime, delayed, available, offline }

/// Computed entry for a driver shown in the live fleet list.
class _FleetEntry {
  final String driverId;
  final String driverName;
  final _FleetDriverStatus status;
  final String statusLabel;

  const _FleetEntry({
    required this.driverId,
    required this.driverName,
    required this.status,
    required this.statusLabel,
  });
}

/// Live fleet panel — right column of the dispatcher split view.
///
/// Derives driver list from RideBloc: all rides with a driverName set and
/// status != completed/cancelled. When no data is present it shows a
/// placeholder note.
///
/// Pixel spec: theme card, header "Live fleet" 14px w700, driver rows pad9/18:
/// avatar30 + name 13px w600 + status 11px + status dot 8px
/// (red=delayed / green=available / teal=on-time / gray=offline).
class LiveFleetPanel extends StatelessWidget {
  const LiveFleetPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppStyles.primaryCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: BlocBuilder<RideBloc, RideState>(
              buildWhen: (prev, curr) => prev.rides != curr.rides,
              builder: (context, state) {
                final entries = _buildEntries(state.rides);
                if (entries.isEmpty) {
                  return _buildPlaceholder(context);
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _DriverRow(entry: entries[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_taxi, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          const Text(
            'Live fleet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.map_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fleet map not available',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Driver list derived from active rides',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Builds the fleet list from active rides in the RideBloc state.
  List<_FleetEntry> _buildEntries(List<Ride> rides) {
    final activeRides = rides
        .where(
          (r) =>
              r.status != RideStatus.completed &&
              r.status != RideStatus.cancelled &&
              r.driverName != null &&
              r.driverId != null,
        )
        .toList();

    // Deduplicate by driverId — keep the most recent ride per driver.
    final seen = <String>{};
    final entries = <_FleetEntry>[];
    for (final ride in activeRides) {
      final driverId = ride.driverId!;
      if (seen.contains(driverId)) continue;
      seen.add(driverId);

      final status = _statusFor(ride);
      final statusLabel = _labelFor(ride, status);
      entries.add(
        _FleetEntry(
          driverId: driverId,
          driverName: ride.driverName!,
          status: status,
          statusLabel: statusLabel,
        ),
      );
    }
    return entries;
  }

  _FleetDriverStatus _statusFor(Ride ride) {
    if (ride.status == RideStatus.inProgress) return _FleetDriverStatus.onTime;
    if (ride.status == RideStatus.assigned) return _FleetDriverStatus.available;
    return _FleetDriverStatus.offline;
  }

  String _labelFor(Ride ride, _FleetDriverStatus status) {
    switch (status) {
      case _FleetDriverStatus.onTime:
        final time = DateFormat('HH:mm').format(ride.pickupDateTime);
        return 'In progress · pickup $time';
      case _FleetDriverStatus.available:
        final time = DateFormat('HH:mm').format(ride.pickupDateTime);
        return 'Assigned · pickup $time';
      case _FleetDriverStatus.delayed:
        return 'Delayed';
      case _FleetDriverStatus.offline:
        return 'Offline';
    }
  }
}

class _DriverRow extends StatelessWidget {
  final _FleetEntry entry;

  const _DriverRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotColor = _dotColor(entry.status);
    final initials = entry.driverName.isNotEmpty
        ? entry.driverName
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar 30px
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.driverName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status dot 8px
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Color _dotColor(_FleetDriverStatus status) {
    switch (status) {
      case _FleetDriverStatus.delayed:
        return AppColors.error; // red
      case _FleetDriverStatus.available:
        return AppColors.success; // green
      case _FleetDriverStatus.onTime:
        return AppColors.rideInProgress; // teal
      case _FleetDriverStatus.offline:
        return AppColors.textLight; // gray
    }
  }
}

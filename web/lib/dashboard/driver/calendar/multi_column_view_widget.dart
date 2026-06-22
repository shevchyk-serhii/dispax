import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../modules/core/navigation_helper.dart';
import 'widgets/ride_calendar_card.dart';

/// Multi-column calendar board: shows up to 3 drivers' rides side by side for a
/// given day. Each column is headed by the driver's name.
///
/// Uses a local [FutureBuilder] (not [RideBloc]) so it doesn't interfere with
/// the live-ETA stream. The future is re-fetched when [selectedDay] or [drivers]
/// change via [didUpdateWidget].
class MultiColumnViewWidget extends StatefulWidget {
  final DateTime selectedDay;

  /// The drivers to display as columns (include self if desired). At most 3 are
  /// shown; when more than 3 are passed a "+N more" indicator is shown.
  final List<Person> drivers;

  /// Called when a ride card is tapped.
  final void Function(Ride) onRideSelected;

  const MultiColumnViewWidget({
    super.key,
    required this.selectedDay,
    required this.drivers,
    required this.onRideSelected,
  });

  @override
  State<MultiColumnViewWidget> createState() => _MultiColumnViewWidgetState();
}

class _MultiColumnViewWidgetState extends State<MultiColumnViewWidget> {
  static const int _maxColumns = 3;

  late Future<List<Ride>> _ridesFuture;
  late RideService _rideService;

  @override
  void initState() {
    super.initState();
    _rideService = RideService(apiClient: context.read<AuthBloc>().apiClient);
    _ridesFuture = _fetchRides();
  }

  @override
  void didUpdateWidget(MultiColumnViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay ||
        oldWidget.drivers != widget.drivers) {
      setState(() {
        _ridesFuture = _fetchRides();
      });
    }
  }

  @override
  void dispose() {
    _rideService.dispose();
    super.dispose();
  }

  Future<List<Ride>> _fetchRides() {
    final ids = widget.drivers.take(_maxColumns).map((d) => d.id).toList();
    return _rideService.getRidesByDrivers(ids, widget.selectedDay);
  }

  void _handlePriceEdited(Ride ride, double newPrice) {
    _rideService
        .setRidePrice(ride.id, newPrice)
        .then((_) {
          if (mounted) {
            setState(() {
              _ridesFuture = _fetchRides();
            });
          }
        })
        .catchError((Object e) {
          if (mounted) {
            NavigationHelper.showSnackBar(
              context,
              'Failed to set price: $e',
              isError: true,
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleDrivers = widget.drivers.take(_maxColumns).toList();
    final extraCount = widget.drivers.length - visibleDrivers.length;

    return Column(
      children: [
        if (extraCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Showing first 3 drivers — +$extraCount more',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Ride>>(
            future: _ridesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load rides',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                );
              }
              final allRides = snapshot.data ?? [];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: visibleDrivers.map((driver) {
                  final driverRides =
                      allRides.where((r) => r.driverId == driver.id).toList()
                        ..sort(
                          (a, b) =>
                              a.pickupDateTime.compareTo(b.pickupDateTime),
                        );
                  return Expanded(
                    child: _DriverColumn(
                      driver: driver,
                      rides: driverRides,
                      onRideSelected: widget.onRideSelected,
                      onPriceEdited: _handlePriceEdited,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single driver column in the board view.
class _DriverColumn extends StatelessWidget {
  final Person driver;
  final List<Ride> rides;
  final void Function(Ride) onRideSelected;
  final void Function(Ride, double) onPriceEdited;

  const _DriverColumn({
    required this.driver,
    required this.rides,
    required this.onRideSelected,
    required this.onPriceEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(80),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              driver.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // Rides list or empty state
          Expanded(
            child: rides.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      return RideCalendarCard(
                        ride: ride,
                        onTap: () => onRideSelected(ride),
                        onPriceEdited: (price) => onPriceEdited(ride, price),
                        showActions: false,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color: colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          const SizedBox(height: 8),
          Text(
            'No rides',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

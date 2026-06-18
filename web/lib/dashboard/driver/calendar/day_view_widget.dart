import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/core/navigation_utils.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_colors.dart';
import 'widgets/ride_badges.dart';

class DayViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(Ride) onRideSelected;

  const DayViewWidget({
    super.key,
    required this.selectedDay,
    required this.onRideSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        final dayRides = getRidesForDay(rideState.rides, selectedDay);
        dayRides.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildDayHeader(context),
              Expanded(
                child: dayRides.isEmpty
                    ? buildEmptyState(context)
                    : buildRidesList(context, dayRides),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildDayHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(60),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.EEEE().format(selectedDay),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                DateFormat.yMMMd().format(selectedDay),
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isSameDay(selectedDay, DateTime.now()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No rides scheduled',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free day!',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget buildRidesList(BuildContext context, List<Ride> rides) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length + getTravelTimeSlots(rides).length,
      itemBuilder: (context, index) {
        final items = buildTimelineItems(context, rides);
        if (index >= items.length) return const SizedBox.shrink();
        return items[index];
      },
    );
  }

  List<Widget> buildTimelineItems(BuildContext context, List<Ride> rides) {
    final items = <Widget>[];

    for (int i = 0; i < rides.length; i++) {
      final ride = rides[i];
      items.add(buildRideCard(context, ride, i == rides.length - 1));

      if (i < rides.length - 1) {
        final nextRide = rides[i + 1];
        final travelTime = nextRide.pickupDateTime
            .difference(ride.pickupDateTime)
            .inMinutes;
        items.add(buildTravelTimeIndicator(context, travelTime));
      }
    }

    return items;
  }

  Widget buildRideCard(BuildContext context, Ride ride, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = RideStatusStyles.getStatusColor(ride.status);
    final statusText = RideStatusStyles.getStatusLabel(ride.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onRideSelected(ride),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            border: Border.all(color: statusColor.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        DateFormat.Hm().format(ride.pickupDateTime),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (ride.price != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '€${ride.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              RideBadges.chips(context, ride),
              const SizedBox(height: 12),
              buildLocationRow(
                context,
                Icons.person,
                'Client',
                ride.clientName,
              ),
              const SizedBox(height: 8),
              buildLocationRow(
                context,
                Icons.location_on,
                'From',
                ride.from.address,
              ),
              const SizedBox(height: 8),
              buildLocationRow(context, Icons.flag, 'To', ride.to.address),
              RideBadges.requirements(context, ride),
              const SizedBox(height: 12),
              buildActionButtons(context, ride),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLocationRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context, Ride ride) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _handleCall(context, ride),
                icon: const Icon(Icons.phone, color: AppColors.success),
                tooltip: 'Call Client',
              ),
              IconButton(
                onPressed: () => _handleNavigation(context, ride),
                icon: const Icon(Icons.navigation, color: AppColors.info),
                tooltip: 'Start Navigation',
              ),
            ],
          ),
        ),
        if (ride.status == RideStatus.assigned)
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<RideBloc>().add(
                  RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.inProgress,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          )
        else if (ride.status == RideStatus.inProgress)
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<RideBloc>().add(
                  RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.completed,
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _handleCall(BuildContext context, Ride ride) {
    final phone = ride.client.phone;
    if (phone == null || phone.isEmpty) {
      NavigationHelper.showSnackBar(
        context,
        'No phone number available',
        isError: true,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.success),
              title: const Text('Call'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppColors.info),
              title: const Text('SMS'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('sms:$phone'));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, Ride ride) async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Navigate to'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'pickup'),
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppColors.success,
                ),
                title: Text(ride.from.address),
                subtitle: const Text('Pickup location'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'dropoff'),
              child: ListTile(
                leading: const Icon(Icons.flag, color: AppColors.error),
                title: Text(ride.to.address),
                subtitle: const Text('Drop-off location'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'waze_pickup'),
              child: const ListTile(
                leading: Icon(Icons.map, color: AppColors.accent),
                title: Text('Open in Waze'),
                subtitle: Text('Pickup location'),
              ),
            ),
          ],
        ),
      );

      if (choice == null) return;

      switch (choice) {
        case 'pickup':
          await NavigationUtils.openGoogleMapsNavigation(ride.from);
        case 'dropoff':
          await NavigationUtils.openGoogleMapsNavigation(ride.to);
        case 'waze_pickup':
          await NavigationUtils.openWazeNavigation(ride.from);
      }
    } catch (e) {
      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          'Could not open navigation: $e',
          isError: true,
        );
      }
    }
  }

  Widget buildTravelTimeIndicator(BuildContext context, int minutes) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 30,
            color: colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Icon(
            Icons.directions_car,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$minutes min travel time',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<Ride> getRidesForDay(List<Ride> rides, DateTime day) {
    return rides.where((ride) {
      final rideDate = DateTime(
        ride.pickupDateTime.year,
        ride.pickupDateTime.month,
        ride.pickupDateTime.day,
      );
      final targetDate = DateTime(day.year, day.month, day.day);
      return rideDate == targetDate;
    }).toList();
  }

  List<int> getTravelTimeSlots(List<Ride> rides) {
    final travelTimes = <int>[];
    for (int i = 0; i < rides.length - 1; i++) {
      final currentRide = rides[i];
      final nextRide = rides[i + 1];
      final travelTime = nextRide.pickupDateTime
          .difference(currentRide.pickupDateTime)
          .inMinutes;
      travelTimes.add(travelTime);
    }
    return travelTimes;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../modules/core/navigation_utils.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../constants/app_colors.dart';

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
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        return BlocBuilder<ScheduleBloc, ScheduleState>(
          builder: (context, scheduleState) {
            final dayRides = getRidesForDay(rideState.rides, selectedDay);
            dayRides.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));

            final daySchedules = scheduleState.scheduleDays.where((d) =>
              d.date.year == selectedDay.year &&
              d.date.month == selectedDay.month &&
              d.date.day == selectedDay.day &&
              d.status != ScheduleDayStatus.cancelled
            ).toList();

            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildDayHeader(),
                  if (daySchedules.isNotEmpty)
                    _buildScheduleBlock(daySchedules),
                  Expanded(
                    child: dayRides.isEmpty
                        ? buildEmptyState()
                        : buildRidesList(dayRides),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleBlock(List<ScheduleDay> schedules) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Work Schedule',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...schedules.map((s) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text(
                  '${s.startTime} — ${s.endTime}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _scheduleStatusColor(s.status).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.status.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _scheduleStatusColor(s.status),
                    ),
                  ),
                ),
                if (s.notes != null && s.notes!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.notes!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _scheduleStatusColor(ScheduleDayStatus status) {
    switch (status) {
      case ScheduleDayStatus.scheduled:
        return Colors.blue;
      case ScheduleDayStatus.active:
        return Colors.green;
      case ScheduleDayStatus.completed:
        return Colors.grey;
      case ScheduleDayStatus.cancelled:
        return Colors.red;
    }
  }

  Widget buildDayHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
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
                  color: Colors.blue.shade800,
                ),
              ),
              Text(
                DateFormat.yMMMd().format(selectedDay),
                style: TextStyle(fontSize: 16, color: Colors.blue.shade600),
              ),
            ],
          ),
          if (isSameDay(selectedDay, DateTime.now()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
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

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No rides scheduled',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free day!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget buildRidesList(List<Ride> rides) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length + getTravelTimeSlots(rides).length,
      itemBuilder: (context, index) {
        final items = buildTimelineItems(rides);
        if (index >= items.length) return const SizedBox.shrink();

        return items[index];
      },
    );
  }

  List<Widget> buildTimelineItems(List<Ride> rides) {
    final items = <Widget>[];

    for (int i = 0; i < rides.length; i++) {
      final ride = rides[i];

      items.add(buildRideCard(ride, i == rides.length - 1));

      if (i < rides.length - 1) {
        final nextRide = rides[i + 1];
        final travelTime = nextRide.pickupDateTime
            .difference(ride.pickupDateTime)
            .inMinutes;
        items.add(buildTravelTimeIndicator(travelTime));
      }
    }

    return items;
  }

  Widget buildRideCard(Ride ride, bool isLast) {
    final statusColor = getStatusColor(ride.status);
    final statusText = getStatusText(ride.status);

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
                  Text(
                    DateFormat.Hm().format(ride.pickupDateTime),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
              const SizedBox(height: 12),
              buildLocationRow(Icons.person, 'Client', ride.clientName),
              const SizedBox(height: 8),
              buildLocationRow(Icons.location_on, 'From', ride.from.address),
              const SizedBox(height: 8),
              buildLocationRow(Icons.flag, 'To', ride.to.address),
              const SizedBox(height: 12),
              buildActionButtons(ride),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLocationRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget buildActionButtons(Ride ride) {
    return Builder(
      builder: (context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _handleCall(context, ride),
                  icon: const Icon(Icons.phone, color: Colors.green),
                  tooltip: 'Call Client',
                ),
                IconButton(
                  onPressed: () => _handleNavigation(context, ride),
                  icon: const Icon(Icons.navigation, color: Colors.blue),
                  tooltip: 'Start Navigation',
                ),
              ],
            ),
          ),
          if (ride.status == RideStatus.assigned)
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<RideBloc>().add(RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.inProgress,
                  ));
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else if (ride.status == RideStatus.inProgress)
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<RideBloc>().add(RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.completed,
                  ));
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleCall(BuildContext context, Ride ride) {
    final phone = ride.client.phone;
    if (phone == null || phone.isEmpty) {
      NavigationHelper.showSnackBar(context, 'No phone number available', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
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
                leading: const Icon(Icons.location_on, color: Colors.green),
                title: Text(ride.from.address),
                subtitle: const Text('Pickup location'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'dropoff'),
              child: ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: Text(ride.to.address),
                subtitle: const Text('Drop-off location'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'waze_pickup'),
              child: const ListTile(
                leading: Icon(Icons.map, color: Colors.teal),
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
        NavigationHelper.showSnackBar(context, 'Could not open navigation: $e', isError: true);
      }
    }
  }

  Widget buildTravelTimeIndicator(int minutes) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 30,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Icon(Icons.directions_car, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            '$minutes min travel time',
            style: TextStyle(
              color: Colors.grey.shade600,
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

  Color getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequested;
      case RideStatus.assigned:
        return AppColors.rideAssigned;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
    }
  }

  String getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'REQUESTED';
      case RideStatus.assigned:
        return 'ASSIGNED';
      case RideStatus.inProgress:
        return 'IN PROGRESS';
      case RideStatus.completed:
        return 'COMPLETED';
      case RideStatus.cancelled:
        return 'CANCELLED';
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

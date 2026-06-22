import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../driver/calendar/widgets/ride_calendar_card.dart';

/// Day-view for the client calendar.
///
/// Renders rides for [selectedDay] using [RideCalendarCard] in read-only mode
/// (no price editing, no driver action buttons). Tapping a card calls
/// [onRideSelected].
class ClientDayViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final void Function(Ride) onRideSelected;

  const ClientDayViewWidget({
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

        // The selected date already shows in CalendarControls above, so the
        // day card no longer repeats a large "Weekday / Date" header — that
        // freed vertical space goes to the ride cards. A small "Today" chip is
        // kept (only when the selected day is today) as a quick visual cue.
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
              if (isSameDay(selectedDay, DateTime.now())) buildTodayChip(),
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

  Widget buildTodayChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Today',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
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
            'No rides for this day',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget buildRidesList(BuildContext context, List<Ride> rides) {
    // Build the interleaved card/travel-time items once, not per itemBuilder
    // call, so scrolling stays O(n) instead of O(n^2).
    final items = buildTimelineItems(context, rides);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  List<Widget> buildTimelineItems(BuildContext context, List<Ride> rides) {
    final items = <Widget>[];

    for (int i = 0; i < rides.length; i++) {
      final ride = rides[i];
      items.add(
        RideCalendarCard(
          ride: ride,
          onTap: () => onRideSelected(ride),
          onPriceEdited: null,
          showActions: false,
          actionsWidget: null,
        ),
      );

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

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

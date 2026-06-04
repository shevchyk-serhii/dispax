import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';

class MonthViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onMonthChanged;

  const MonthViewWidget({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.all(16),
          child: TableCalendar<Ride>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            calendarFormat: CalendarFormat.month,
            eventLoader: (day) => getRidesForDay(rideState.rides, day),
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              onDaySelected(selectedDay);
            },
            onPageChanged: (focusedDay) {
              onMonthChanged(focusedDay);
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Colors.blue,
                size: 28,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Colors.blue,
                size: 28,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.orange.shade400,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerSize: 8,
            ),
            calendarBuilders: CalendarBuilders<Ride>(
              markerBuilder: (context, day, rides) {
                if (rides.isEmpty) return null;

                return Positioned(
                  right: 1,
                  bottom: 1,
                  child: buildRideCountIndicator(rides.length),
                );
              },
              dowBuilder: (context, day) {
                final text = DateFormat.E().format(day);
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: day.weekday >= 6
                          ? Colors.red.shade600
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
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

  Widget buildRideCountIndicator(int count) {
    Color color;
    if (count <= 2) {
      color = Colors.green;
    } else if (count <= 4) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

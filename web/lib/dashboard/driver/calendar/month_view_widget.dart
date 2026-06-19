import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import 'widgets/ride_badges.dart';

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
      buildWhen: (prev, curr) => prev.rides != curr.rides,
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
                color: AppColors.info,
                size: 28,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: AppColors.info,
                size: 28,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: AppColors.error),
              holidayTextStyle: const TextStyle(color: AppColors.error),
              selectedDecoration: BoxDecoration(
                color: AppColors.infoStrong,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerSize: 8,
            ),
            calendarBuilders: CalendarBuilders<Ride>(
              markerBuilder: (context, day, rides) {
                if (rides.isEmpty) return null;

                return Stack(
                  children: [
                    Positioned(
                      left: 1,
                      bottom: 2,
                      child: RideBadges.dayMarkers(context, rides, size: 10),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: buildRideCountIndicator(rides.length),
                    ),
                  ],
                );
              },
              dowBuilder: (context, day) {
                final text = DateFormat.E().format(day);
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: day.weekday >= 6
                          ? AppColors.errorStrong
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
      color = AppColors.success;
    } else if (count <= 4) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
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

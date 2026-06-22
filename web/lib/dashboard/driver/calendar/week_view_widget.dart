import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_colors.dart';
import 'widgets/ride_badges.dart';

class WeekViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onWeekChanged;

  /// When set, only rides assigned to this driver are shown. Null shows all
  /// rides (back-compat). Follows the schedule screen's driver dropdown.
  final String? driverIdFilter;

  const WeekViewWidget({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onWeekChanged,
    this.driverIdFilter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        final weekDays = getWeekDays(selectedDay);

        return Container(
          height: 400,
          margin: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              buildWeekHeader(context, weekDays),
              Expanded(
                child: buildWeekTimeline(context, weekDays, rideState.rides),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DateTime> getWeekDays(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  Widget buildWeekHeader(BuildContext context, List<DateTime> weekDays) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        // Light keeps the intentional blue tint; dark uses a neutral surface.
        color: isDark ? colorScheme.surfaceContainerHighest : AppColors.infoBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 60),
          ...weekDays.map(
            (day) => Expanded(
              child: GestureDetector(
                onTap: () => onDaySelected(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSameDay(day, selectedDay)
                        ? AppColors.infoStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E().format(day),
                        style: TextStyle(
                          color: isSameDay(day, selectedDay)
                              ? Colors.white
                              : (day.weekday >= 6
                                    ? AppColors.errorStrong
                                    : colorScheme.onSurfaceVariant),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isSameDay(day, selectedDay)
                              ? Colors.white
                              : (isSameDay(day, DateTime.now())
                                    ? AppColors.warning
                                    : colorScheme.onSurface),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeekTimeline(
    BuildContext context,
    List<DateTime> weekDays,
    List<Ride> rides,
  ) {
    return SingleChildScrollView(
      child: SizedBox(
        height: 17 * 40.0,
        child: Row(
          children: [
            buildTimeColumn(context),
            ...weekDays.map(
              (day) => Expanded(child: buildDayColumn(context, day, rides)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTimeColumn(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 60,
      child: Column(
        children: List.generate(17, (index) {
          final hour = index + 6;
          return Container(
            height: 40,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildDayColumn(BuildContext context, DateTime day, List<Ride> rides) {
    final colorScheme = Theme.of(context).colorScheme;
    final dayRides = getRidesForDay(rides, day);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      child: Stack(
        children: [
          ...List.generate(
            17,
            (index) => Positioned(
              top: index * 40.0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: colorScheme.surfaceContainerLow,
              ),
            ),
          ),

          ...dayRides.map((ride) => buildRideBlock(ride)),
        ],
      ),
    );
  }

  Widget buildRideBlock(Ride ride) {
    final startHour = ride.pickupDateTime.hour;
    final startMinute = ride.pickupDateTime.minute;
    final duration = 1.5;

    final top = ((startHour - 6) * 40.0) + (startMinute / 60 * 40.0);
    final height = duration * 40.0;

    Color color = RideStatusStyles.getStatusColor(ride.status);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Tooltip(
        message: RideBadges.tooltip(ride),
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(204),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.Hm().format(ride.pickupDateTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RideBadges.blockMarkers(ride),
                ],
              ),
              if (height > 30)
                Flexible(
                  child: Text(
                    ride.clientName,
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (height > 50)
                Flexible(
                  child: Text(
                    ride.to.address,
                    style: const TextStyle(color: Colors.white70, fontSize: 8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Ride> getRidesForDay(List<Ride> rides, DateTime day) {
    return rides.where((ride) {
      if (driverIdFilter != null && ride.driverId != driverIdFilter) {
        return false;
      }
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

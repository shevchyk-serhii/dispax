import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_colors.dart';
import 'shift_window.dart';
import 'widgets/ride_badges.dart';

class WeekViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onWeekChanged;

  /// When set, only rides assigned to this driver are shown. Null shows all
  /// rides (back-compat). Follows the schedule screen's driver dropdown.
  final String? driverIdFilter;

  /// When non-null, the calendar renders exactly this list instead of the
  /// shared RideBloc's rides. The dispatcher calendar uses it to show the
  /// selected driver's rides (loaded on demand) without touching the shared
  /// RideBloc that feeds the other dashboard tabs. The list is assumed to be
  /// already scoped to the chosen driver, so [driverIdFilter] is a no-op for it.
  final List<Ride>? ridesOverride;

  /// Called when a ride block is tapped. When null the block is not tappable
  /// (back-compat). Mirrors DayViewWidget / MultiColumnViewWidget so tapping a
  /// week block opens the ride details screen.
  final Function(Ride)? onRideSelected;

  /// The displayed driver's work shifts. Each shift renders as a translucent
  /// background band behind the ride blocks of its day, so availability is
  /// visible at a glance. Cancelled shifts must be filtered out by the caller.
  final List<ScheduleDay> shifts;

  const WeekViewWidget({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onWeekChanged,
    this.driverIdFilter,
    this.ridesOverride,
    this.onRideSelected,
    this.shifts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ridesOverride = this.ridesOverride;
    if (ridesOverride != null) {
      return _buildBody(context, colorScheme, ridesOverride);
    }
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) =>
          _buildBody(context, colorScheme, rideState.rides),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    List<Ride> rides,
  ) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fill the available width when all seven columns fit; otherwise fall
          // back to the minimum width and scroll the whole grid horizontally so
          // the ride-block text stays readable. The header and the timeline
          // share one horizontal scroll view so their columns stay aligned and
          // scroll together.
          final fitWidth = (constraints.maxWidth - _timeColumnWidth) / 7;
          final columnWidth = fitWidth > _minDayColumnWidth
              ? fitWidth
              : _minDayColumnWidth;
          final gridWidth = _timeColumnWidth + columnWidth * 7;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: gridWidth,
              child: Column(
                children: [
                  buildWeekHeader(context, weekDays, columnWidth),
                  Expanded(
                    child: buildWeekTimeline(
                      context,
                      weekDays,
                      rides,
                      columnWidth,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<DateTime> getWeekDays(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  Widget buildWeekHeader(
    BuildContext context,
    List<DateTime> weekDays,
    double columnWidth,
  ) {
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
          const SizedBox(width: _timeColumnWidth),
          ...weekDays.map(
            (day) => SizedBox(
              width: columnWidth,
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

  /// Width of the left time gutter ("06:00 …") column.
  static const double _timeColumnWidth = 60;

  /// Minimum width of a single day column. Narrow screens cannot fit all seven
  /// days at this width, so the week grid scrolls horizontally instead of
  /// squeezing the ride blocks until their text is unreadable.
  static const double _minDayColumnWidth = 140;

  Widget buildWeekTimeline(
    BuildContext context,
    List<DateTime> weekDays,
    List<Ride> rides,
    double columnWidth,
  ) {
    // Vertical scroll only — the enclosing _buildBody owns the shared horizontal
    // scroll so the header and timeline columns stay aligned.
    return SingleChildScrollView(
      child: SizedBox(
        height: 17 * 40.0,
        child: Row(
          children: [
            buildTimeColumn(context),
            ...weekDays.map(
              (day) => SizedBox(
                width: columnWidth,
                child: buildDayColumn(context, day, rides),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTimeColumn(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _timeColumnWidth,
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
    final dayShifts = getShiftsForDay(day);

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

          // Shift bands go under the ride blocks: they mark availability, the
          // rides sit on top of them.
          ...dayShifts.map((shift) => buildShiftBand(context, shift)),

          ...dayRides.map((ride) => buildRideBlock(context, ride)),
        ],
      ),
    );
  }

  /// Translucent availability band for one shift, rendered behind the rides.
  /// The grid shows 06:00–23:00 (17 rows of 40 px); the shared
  /// [visibleShiftSegment] clips the shift into that window and keeps the
  /// evening segment of a shift crossing midnight (22:00–06:00) — which used
  /// to vanish entirely (negative height after clamping both ends).
  Widget buildShiftBand(BuildContext context, ScheduleDay shift) {
    final segment = visibleShiftSegment(
      parseShiftHour(shift.startTime),
      parseShiftHour(shift.endTime),
    );
    if (segment == null) return const SizedBox.shrink();
    final top = (segment.start - 6) * 40.0;
    final height = (segment.end - segment.start) * 40.0;

    return Positioned(
      key: ValueKey('shift-band-${shift.id}'),
      top: top,
      left: 1,
      right: 1,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: AppColors.success, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 6, top: 2),
        alignment: Alignment.topLeft,
        child: Text(
          '${_hhmm(shift.startTime)}–${_hhmm(shift.endTime)}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      ),
    );
  }

  static String _hhmm(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;

  List<ScheduleDay> getShiftsForDay(DateTime day) => shifts
      .where(
        (s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      )
      .toList();

  Widget buildRideBlock(BuildContext context, Ride ride) {
    final startHour =
        ride.pickupDateTime.hour + ride.pickupDateTime.minute / 60.0;
    const duration = 1.5;
    // The grid shows 06:00–23:00 (17 rows of 40 px). Clip the block into that
    // window via the shared helper — a 02:00 ride used to render at
    // top = −160 above the grid, a 22:30 one below its bottom edge.
    const gridHeight = 17 * 40.0;
    final segment = visibleBlockSegment(startHour, startHour + duration);
    final height = ((segment.end - segment.start) * 40.0).clamp(
      10.0,
      gridHeight,
    );
    final top = ((segment.start - 6) * 40.0).clamp(0.0, gridHeight - height);

    Color color = RideStatusStyles.getStatusColor(ride.status);

    final onTap = onRideSelected;
    return Positioned(
      key: ValueKey('week-ride-${ride.id}'),
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap(ride),
        child: Tooltip(
          message: RideBadges.tooltip(context, ride),
          waitDuration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              color: color.withAlpha(204),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            // A block clipped to the window edge can be shorter than its
            // one-line content — hide the content instead of overflowing.
            child: height < 26
                ? null
                : Column(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (height > 50)
                        Flexible(
                          child: Text(
                            ride.to.address,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
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

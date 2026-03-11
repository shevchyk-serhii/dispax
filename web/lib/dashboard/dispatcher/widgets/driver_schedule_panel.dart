import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../utils/conflict_detector.dart';
import 'assignment_dialog.dart';

class DriverSchedulePanel extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DriverSchedulePanel({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<DriverSchedulePanel> createState() => _DriverSchedulePanelState();
}

class _DriverSchedulePanelState extends State<DriverSchedulePanel> {
  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    context.read<ScheduleBloc>().add(ScheduleLoadForDate(date: widget.selectedDate));
  }

  @override
  void didUpdateWidget(DriverSchedulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadSchedule();
    }
  }

  void _changeDate(int days) {
    widget.onDateChanged(widget.selectedDate.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildDateSelector(),
        Expanded(
          child: BlocBuilder<ScheduleBloc, ScheduleState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(state.errorMessage ?? 'Error loading schedules'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadSchedule, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final days = state.scheduleDays
                  .where((d) =>
                    d.date.year == widget.selectedDate.year &&
                    d.date.month == widget.selectedDate.month &&
                    d.date.day == widget.selectedDate.day &&
                    d.status != ScheduleDayStatus.cancelled)
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

              if (days.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async => _loadSchedule(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    return _DriverScheduleDropTarget(scheduleDay: days[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.calendar_view_day, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Driver Schedules',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadSchedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final isToday = _isSameDay(widget.selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDate(-1),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                widget.onDateChanged(picked);
              }
            },
            child: Column(
              children: [
                Text(
                  DateFormat.EEEE().format(widget.selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColors.dispatcherColor : AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat.yMMMd().format(widget.selectedDate),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No drivers scheduled',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMd().format(widget.selectedDate),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DriverScheduleDropTarget extends StatelessWidget {
  final ScheduleDay scheduleDay;

  const _DriverScheduleDropTarget({required this.scheduleDay});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        final driverRides = rideState.rides
            .where((r) => r.driverId == scheduleDay.driverId &&
                          r.status != RideStatus.cancelled &&
                          r.status != RideStatus.completed)
            .toList();

        final rideCount = driverRides.length;
        final loadColor = rideCount == 0
            ? Colors.green
            : rideCount <= 2
                ? Colors.orange
                : Colors.red;

        return DragTarget<Ride>(
          onWillAcceptWithDetails: (details) {
            return details.data.status == RideStatus.requested;
          },
          onAcceptWithDetails: (details) {
            final ride = details.data;
            final conflicts = ConflictDetector.findConflicts(ride, driverRides);
            final driverLabel = scheduleDay.notes?.isNotEmpty == true
                ? scheduleDay.notes!
                : 'Driver ${scheduleDay.driverId.length > 8 ? scheduleDay.driverId.substring(0, 8) : scheduleDay.driverId}...';

            showDialog(
              context: context,
              builder: (_) => AssignmentDialog(
                ride: ride,
                driverLabel: driverLabel,
                driverId: scheduleDay.driverId,
                conflicts: conflicts,
                onConfirm: () {
                  context.read<RideBloc>().add(RideAssignRequested(
                    rideId: ride.id,
                    driverId: scheduleDay.driverId,
                  ));
                },
              ),
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHovering
                    ? BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide.none,
              ),
              elevation: isHovering ? 4 : 2,
              color: isHovering ? AppColors.rideAssignedBg : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: loadColor, width: 4)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 18, color: Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Driver ${scheduleDay.driverId.length > 8 ? scheduleDay.driverId.substring(0, 8) : scheduleDay.driverId}...',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: loadColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: loadColor.withAlpha(100)),
                          ),
                          child: Text(
                            '$rideCount ride${rideCount == 1 ? '' : 's'}',
                            style: TextStyle(color: loadColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${scheduleDay.startTime} — ${scheduleDay.endTime}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (driverRides.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...driverRides.take(3).map((ride) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car, size: 12, color: AppColors.rideAssigned),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${DateFormat('HH:mm').format(ride.pickupDateTime)} ${ride.from.address}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (driverRides.length > 3)
                        Text(
                          '+${driverRides.length - 3} more',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                    ],
                    if (isHovering)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withAlpha(60)),
                          ),
                          child: const Text(
                            'Drop here to assign',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

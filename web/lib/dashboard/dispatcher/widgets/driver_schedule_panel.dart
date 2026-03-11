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

enum _LoadFilter { all, available, moderate, busy }

class _DriverSchedulePanelState extends State<DriverSchedulePanel> {
  String _searchQuery = '';
  _LoadFilter _loadFilter = _LoadFilter.all;

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

  String _driverLabel(ScheduleDay d) =>
      d.notes?.isNotEmpty == true
          ? d.notes!
          : 'Driver ${d.driverId.length > 8 ? d.driverId.substring(0, 8) : d.driverId}...';

  int _driverRideCount(ScheduleDay d, List<Ride> allRides) =>
      allRides.where((r) =>
          r.driverId == d.driverId &&
          r.status != RideStatus.cancelled &&
          r.status != RideStatus.completed).length;

  List<ScheduleDay> _applyFilters(List<ScheduleDay> days, List<Ride> allRides) {
    var filtered = days;

    // Search by driver name
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) => _driverLabel(d).toLowerCase().contains(q)).toList();
    }

    // Filter by load
    switch (_loadFilter) {
      case _LoadFilter.available:
        filtered = filtered.where((d) => _driverRideCount(d, allRides) == 0).toList();
      case _LoadFilter.moderate:
        filtered = filtered.where((d) {
          final c = _driverRideCount(d, allRides);
          return c >= 1 && c <= 2;
        }).toList();
      case _LoadFilter.busy:
        filtered = filtered.where((d) => _driverRideCount(d, allRides) >= 3).toList();
      case _LoadFilter.all:
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildDateSelector(),
        _buildFilterBar(),
        Expanded(
          child: BlocBuilder<ScheduleBloc, ScheduleState>(
            builder: (context, scheduleState) {
              if (scheduleState.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (scheduleState.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(scheduleState.errorMessage ?? 'Error loading schedules'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadSchedule, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final allDays = scheduleState.scheduleDays
                  .where((d) =>
                    d.date.year == widget.selectedDate.year &&
                    d.date.month == widget.selectedDate.month &&
                    d.date.day == widget.selectedDate.day &&
                    d.status != ScheduleDayStatus.cancelled)
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

              return BlocBuilder<RideBloc, RideState>(
                builder: (context, rideState) {
                  final days = _applyFilters(allDays, rideState.rides);

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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search driver name...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildLoadChip('All', _LoadFilter.all, Colors.grey),
              const SizedBox(width: 6),
              _buildLoadChip('Available', _LoadFilter.available, Colors.green),
              const SizedBox(width: 6),
              _buildLoadChip('Moderate', _LoadFilter.moderate, Colors.orange),
              const SizedBox(width: 6),
              _buildLoadChip('Busy', _LoadFilter.busy, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadChip(String label, _LoadFilter filter, Color color) {
    final selected = _loadFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _loadFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
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

  void _showReassignSheet(BuildContext context, Ride ride) {
    final scheduleState = context.read<ScheduleBloc>().state;
    final rideState = context.read<RideBloc>().state;

    final otherDrivers = scheduleState.scheduleDays
        .where((d) => d.driverId != ride.driverId && d.status != ScheduleDayStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (otherDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other drivers available for reassignment.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reassign Ride',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ride.clientName} — ${DateFormat('dd.MM HH:mm').format(ride.pickupDateTime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: otherDrivers.length,
                itemBuilder: (_, index) {
                  final schedule = otherDrivers[index];
                  final driverRides = rideState.rides
                      .where((r) => r.driverId == schedule.driverId &&
                                    r.status != RideStatus.cancelled &&
                                    r.status != RideStatus.completed)
                      .toList();
                  final conflicts = ConflictDetector.findConflicts(ride, driverRides);
                  final rideCount = driverRides.length;
                  final loadColor = rideCount == 0
                      ? Colors.green
                      : rideCount <= 2
                          ? Colors.orange
                          : Colors.red;

                  final driverLabel = schedule.notes?.isNotEmpty == true
                      ? schedule.notes!
                      : 'Driver ${schedule.driverId.length > 8 ? schedule.driverId.substring(0, 8) : schedule.driverId}...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: conflicts.isNotEmpty ? Colors.red.withAlpha(100) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: loadColor.withAlpha(40),
                        child: Icon(Icons.person, color: loadColor),
                      ),
                      title: Text(driverLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$rideCount ride${rideCount == 1 ? '' : 's'} assigned'),
                          if (conflicts.isNotEmpty)
                            Text(
                              '${conflicts.length} time conflict${conflicts.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.swap_horiz, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm Reassignment'),
                            content: Text('Reassign ${ride.clientName} to $driverLabel?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.read<RideBloc>().add(RideReassignRequested(
                                    rideId: ride.id,
                                    newDriverId: schedule.driverId,
                                  ));
                                },
                                child: const Text('Reassign', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                            if (ride.status == RideStatus.assigned)
                              GestureDetector(
                                onTap: () => _showReassignSheet(context, ride),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(Icons.swap_horiz, size: 16, color: Colors.orange.shade700),
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

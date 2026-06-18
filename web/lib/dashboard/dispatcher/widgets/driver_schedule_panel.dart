import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../utils/conflict_detector.dart';
import 'assignment_dialog.dart';
import 'bulk_reassign_dialog.dart';

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

/// Resolves a human-readable driver label from a schedule day, preferring a
/// real driver name (driverId → name) loaded from `/users/drivers`, then the
/// day's free-text notes, then a truncated id as a last resort.
String resolveDriverLabel(ScheduleDay d, Map<String, String> driverNames) {
  final name = driverNames[d.driverId];
  if (name != null && name.isNotEmpty) return name;
  if (d.notes?.isNotEmpty == true) return d.notes!;
  final id = d.driverId;
  return 'Driver ${id.length > 8 ? id.substring(0, 8) : id}...';
}

class _DriverSchedulePanelState extends State<DriverSchedulePanel> {
  String _searchQuery = '';
  _LoadFilter _loadFilter = _LoadFilter.all;

  /// driverId → display name, loaded once from `/users/drivers`.
  Map<String, String> _driverNames = {};

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _loadRides();
    _loadDriverNames();
  }

  /// The dispatcher dashboard never loads rides on startup (unlike the driver/
  /// client/secretary dashboards), so this panel — which derives each driver's
  /// load from RideBloc — must request them itself, or every driver shows
  /// "0 rides". Reuses the authenticated user from AuthBloc.
  void _loadRides() {
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: user));
    }
  }

  Future<void> _loadDriverNames() async {
    // Reuse the authenticated ApiClient from AuthBloc — never instantiate a
    // bare ApiClient() (it would be missing the auth token → 401).
    final userService = UserService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
    try {
      final drivers = await userService.getDrivers();
      if (!mounted) return;
      setState(() {
        _driverNames = {for (final d in drivers) d.id: d.name};
      });
    } catch (_) {
      // Names are a nicety; on failure we silently fall back to notes/id.
    }
  }

  void _loadSchedule() {
    context.read<ScheduleBloc>().add(
      ScheduleLoadForDate(date: widget.selectedDate),
    );
  }

  @override
  void didUpdateWidget(DriverSchedulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadSchedule();
      _loadRides();
    }
  }

  void _changeDate(int days) {
    widget.onDateChanged(widget.selectedDate.add(Duration(days: days)));
  }

  String _driverLabel(ScheduleDay d) => resolveDriverLabel(d, _driverNames);

  int _driverRideCount(ScheduleDay d, List<Ride> allRides) => allRides
      .where(
        (r) =>
            r.driverId == d.driverId &&
            r.status != RideStatus.cancelled &&
            r.status != RideStatus.completed,
      )
      .length;

  List<ScheduleDay> _applyFilters(List<ScheduleDay> days, List<Ride> allRides) {
    var filtered = days;

    // Search by driver name
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((d) => _driverLabel(d).toLowerCase().contains(q))
          .toList();
    }

    // Filter by load
    switch (_loadFilter) {
      case _LoadFilter.available:
        filtered = filtered
            .where((d) => _driverRideCount(d, allRides) == 0)
            .toList();
      case _LoadFilter.moderate:
        filtered = filtered.where((d) {
          final c = _driverRideCount(d, allRides);
          return c >= 1 && c <= 2;
        }).toList();
      case _LoadFilter.busy:
        filtered = filtered
            .where((d) => _driverRideCount(d, allRides) >= 3)
            .toList();
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        scheduleState.errorMessage ?? 'Error loading schedules',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadSchedule,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final allDays =
                  scheduleState.scheduleDays
                      .where(
                        (d) =>
                            d.date.year == widget.selectedDate.year &&
                            d.date.month == widget.selectedDate.month &&
                            d.date.day == widget.selectedDate.day &&
                            d.status != ScheduleDayStatus.cancelled,
                      )
                      .toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));

              return BlocBuilder<RideBloc, RideState>(
                buildWhen: (prev, curr) => prev.rides != curr.rides,
                builder: (context, rideState) {
                  final days = _applyFilters(allDays, rideState.rides);

                  if (days.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _loadSchedule();
                      _loadRides();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(
                        AppDimensions.paddingMedium,
                      ),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        return _DriverScheduleDropTarget(
                          scheduleDay: days[index],
                          driverNames: _driverNames,
                        );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search driver name...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildLoadChip(
                'All',
                _LoadFilter.all,
                Theme.of(context).colorScheme.onSurfaceVariant,
                colorScheme,
              ),
              const SizedBox(width: 6),
              _buildLoadChip(
                'Available',
                _LoadFilter.available,
                AppColors.success,
                colorScheme,
              ),
              const SizedBox(width: 6),
              _buildLoadChip(
                'Moderate',
                _LoadFilter.moderate,
                AppColors.warning,
                colorScheme,
              ),
              const SizedBox(width: 6),
              _buildLoadChip(
                'Busy',
                _LoadFilter.busy,
                AppColors.error,
                colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadChip(
    String label,
    _LoadFilter filter,
    Color color,
    ColorScheme colorScheme,
  ) {
    final selected = _loadFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _loadFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colorScheme.onSurfaceVariant,
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: () {
                _loadSchedule();
                _loadRides();
              },
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
      color: Theme.of(context).colorScheme.surface,
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
                    color: isToday
                        ? AppColors.dispatcherColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  DateFormat.yMMMd().format(widget.selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 56, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'No drivers scheduled',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMd().format(widget.selectedDate),
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
  final Map<String, String> driverNames;

  const _DriverScheduleDropTarget({
    required this.scheduleDay,
    required this.driverNames,
  });

  void _showReassignSheet(BuildContext context, Ride ride) {
    final scheduleState = context.read<ScheduleBloc>().state;
    final rideState = context.read<RideBloc>().state;

    final otherDrivers =
        scheduleState.scheduleDays
            .where(
              (d) =>
                  d.driverId != ride.driverId &&
                  d.status != ScheduleDayStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (otherDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other drivers available for reassignment.'),
        ),
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
                color: AppColors.warningStrong,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reassign Ride',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                      .where(
                        (r) =>
                            r.driverId == schedule.driverId &&
                            r.status != RideStatus.cancelled &&
                            r.status != RideStatus.completed,
                      )
                      .toList();
                  final conflicts = ConflictDetector.findConflicts(
                    ride,
                    driverRides,
                  );
                  final rideCount = driverRides.length;
                  final loadColor = rideCount == 0
                      ? AppColors.success
                      : rideCount <= 2
                      ? AppColors.warning
                      : AppColors.error;

                  final driverLabel = resolveDriverLabel(schedule, driverNames);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: conflicts.isNotEmpty
                            ? AppColors.error.withAlpha(100)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: loadColor.withAlpha(40),
                        child: Icon(Icons.person, color: loadColor),
                      ),
                      title: Text(
                        driverLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$rideCount ride${rideCount == 1 ? '' : 's'} assigned',
                          ),
                          if (conflicts.isNotEmpty)
                            Text(
                              '${conflicts.length} time conflict${conflicts.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                            content: Text(
                              'Reassign ${ride.clientName} to $driverLabel?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.read<RideBloc>().add(
                                    RideReassignRequested(
                                      rideId: ride.id,
                                      newDriverId: schedule.driverId,
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Reassign',
                                  style: TextStyle(color: Colors.white),
                                ),
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
      buildWhen: (prev, curr) => prev.rides != curr.rides,
      builder: (context, rideState) {
        final driverRides = rideState.rides
            .where(
              (r) =>
                  r.driverId == scheduleDay.driverId &&
                  r.status != RideStatus.cancelled &&
                  r.status != RideStatus.completed,
            )
            .toList();

        final rideCount = driverRides.length;
        final loadColor = rideCount == 0
            ? AppColors.success
            : rideCount <= 2
            ? AppColors.warning
            : AppColors.error;

        return DragTarget<Ride>(
          onWillAcceptWithDetails: (details) {
            return details.data.status == RideStatus.requested;
          },
          onAcceptWithDetails: (details) {
            final ride = details.data;
            final conflicts = ConflictDetector.findConflicts(ride, driverRides);
            final driverLabel = resolveDriverLabel(scheduleDay, driverNames);

            showDialog(
              context: context,
              builder: (_) => AssignmentDialog(
                ride: ride,
                driverLabel: driverLabel,
                driverId: scheduleDay.driverId,
                conflicts: conflicts,
                onConfirm: () {
                  context.read<RideBloc>().add(
                    RideAssignRequested(
                      rideId: ride.id,
                      driverId: scheduleDay.driverId,
                    ),
                  );
                },
              ),
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              // clipBehavior rounds the child so the inner Container's left
              // accent border (a non-uniform Border) doesn't need its own
              // borderRadius, which Flutter forbids in that combination.
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHovering
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              elevation: isHovering ? 4 : 2,
              color: isHovering ? AppColors.rideAssignedBg : null,
              child: Container(
                decoration: BoxDecoration(
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
                            Icon(
                              Icons.person,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              resolveDriverLabel(scheduleDay, driverNames),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rideCount > 0)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BulkReassignDialog(
                                      fromDriverId: scheduleDay.driverId,
                                      fromDriverLabel: resolveDriverLabel(
                                        scheduleDay,
                                        driverNames,
                                      ),
                                      rides: driverRides,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.swap_horiz,
                                    size: 20,
                                    color: AppColors.errorStrong,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: loadColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: loadColor.withAlpha(100),
                                ),
                              ),
                              child: Text(
                                '$rideCount ride${rideCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: loadColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${scheduleDay.startTime} — ${scheduleDay.endTime}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (driverRides.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...driverRides
                          .take(3)
                          .map(
                            (ride) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    size: 12,
                                    color: AppColors.rideAssigned,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${DateFormat('HH:mm').format(ride.pickupDateTime)} ${ride.from.address}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (ride.status == RideStatus.assigned)
                                    GestureDetector(
                                      onTap: () =>
                                          _showReassignSheet(context, ride),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.swap_horiz,
                                          size: 16,
                                          color: AppColors.warningStrong,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      if (driverRides.length > 3)
                        Text(
                          '+${driverRides.length - 3} more',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                    if (isHovering)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.primary.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            'Drop here to assign',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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

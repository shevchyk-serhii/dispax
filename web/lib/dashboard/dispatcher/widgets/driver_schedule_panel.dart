import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/services/error_messages.dart';
import '../../../modules/core/widgets/error_widget.dart';
import '../utils/conflict_detector.dart';
import 'assignment_dialog.dart';
import 'bulk_reassign_dialog.dart';

/// One-line label for a ride in the compact per-driver schedule list:
/// "HH:mm address", with a `✈ <flight> ·` prefix for airport rides so the
/// dispatcher can spot transfers at a glance. For airport rides whose gate is
/// known it appends `· Gate <gate>` so the dispatcher sees the gate without
/// opening the ride. Pure so it is unit-testable without standing up the panel's BLoCs.
String driverScheduleRideLabel(Ride ride, [AppLocalizations? l10n]) {
  final time = DateFormat('HH:mm').format(ride.pickupDateTime);
  if (ride.isAirportTransfer && ride.flightNumber != null) {
    final gatePart = switch (ride.gate) {
      null => '',
      // A remote stand has no real code → its self-describing label, no "Gate" prefix.
      _ when ride.isRemoteGate => '${l10n?.gateRemote ?? 'Bus gate'} · ',
      final g => 'Gate $g · ',
    };
    return '$time ✈ ${ride.flightNumber} · $gatePart${ride.from.address}';
  }
  return '$time ${ride.from.address}';
}

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

/// Below this panel width the board (one column per driver, side by side) is
/// too cramped, so we fall back to the single-column card list. Measured
/// against the panel's own width — in the dispatcher split view the panel is
/// only `flex: 3` of the screen, so the screen being "wide" is not enough.
const double _boardBreakpoint = 720;

/// Fixed width of a single driver column in the board layout.
const double _boardColumnWidth = 300;

/// Resolves a human-readable driver label from a schedule day, preferring a
/// real driver name (driverId → name) loaded from `/users/drivers`, then the
/// day's free-text notes, then a truncated id as a last resort.
String resolveDriverLabel(ScheduleDay d, Map<String, String> driverNames) {
  final name = driverNames[d.driverId];
  if (name != null && name.isNotEmpty) return name;
  final notes = d.notes;
  if (notes != null && notes.isNotEmpty) return notes;
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
                return Center(child: CircularProgressIndicator.adaptive());
              }

              if (scheduleState.hasError) {
                final l10n = AppLocalizations.of(context)!;
                return ErrorDisplayWidget(
                  title: l10n.errorLoadingData,
                  message: friendlyError(
                    scheduleState.error ?? scheduleState.errorMessage,
                    l10n,
                  ),
                  onRetry: _loadSchedule,
                  retryLabel: l10n.retry,
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
                    // Pick the layout from the panel's *own* width, not the
                    // screen's: in the split view this panel is only a fraction
                    // of a "wide" screen.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= _boardBreakpoint) {
                          return _buildBoard(days);
                        }
                        return _buildList(days);
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

  /// Narrow layout: the original single-column list of driver cards.
  Widget _buildList(List<ScheduleDay> days) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      itemCount: days.length,
      itemBuilder: (context, index) {
        return _DriverScheduleDropTarget(
          scheduleDay: days[index],
          driverNames: _driverNames,
        );
      },
    );
  }

  /// Wide layout: one column per driver, side by side with horizontal scroll.
  /// Each column carries the same drop-target / reassign behaviour as a card.
  Widget _buildBoard(List<ScheduleDay> days) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      itemCount: days.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: AppDimensions.paddingMedium),
          child: SizedBox(
            width: _boardColumnWidth,
            child: _DriverScheduleColumn(
              scheduleDay: days[index],
              driverNames: _driverNames,
            ),
          ),
        );
      },
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.dispatcherGradient),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.calendar_view_day,
                color: Colors.white,
                size: 24,
              ),
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
                    // primary stays graphite in light, inverts to light-graphite
                    // in dark (theme handles it) — graphite in light is preserved.
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
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

/// Opens the bottom sheet that lets the dispatcher reassign [ride] to another
/// scheduled driver. Shared by the card list and the board column.
void showReassignSheet(
  BuildContext context,
  Ride ride,
  Map<String, String> driverNames,
) {
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.noDriversAvailableForReassignment)),
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
                      showAdaptiveDialog(
                        context: context,
                        builder: (dlgCtx) {
                          final l10n = AppLocalizations.of(dlgCtx)!;
                          return AlertDialog(
                            title: Text(l10n.confirmReassignment),
                            content: Text(
                              'Reassign ${ride.clientName} to $driverLabel?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dlgCtx),
                                child: Text(l10n.cancel),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                ),
                                onPressed: () {
                                  Navigator.pop(dlgCtx);
                                  context.read<RideBloc>().add(
                                    RideReassignRequested(
                                      rideId: ride.id,
                                      newDriverId: schedule.driverId,
                                      // Conflicts were detected and shown to the
                                      // dispatcher; confirming means "do it
                                      // anyway", so override the backend guard
                                      // instead of bouncing off a 409.
                                      overrideScheduleConflict:
                                          conflicts.isNotEmpty,
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Reassign',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
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

/// A single driver's schedule rendered as a card in the narrow (list) layout.
/// Acts as a drag-and-drop target for assigning a [Ride].
class _DriverScheduleDropTarget extends StatelessWidget {
  final ScheduleDay scheduleDay;
  final Map<String, String> driverNames;

  const _DriverScheduleDropTarget({
    required this.scheduleDay,
    required this.driverNames,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      buildWhen: (prev, curr) => prev.rides != curr.rides,
      builder: (context, rideState) {
        final driverRides =
            rideState.rides
                .where(
                  (r) =>
                      r.driverId == scheduleDay.driverId &&
                      r.status != RideStatus.cancelled &&
                      r.status != RideStatus.completed,
                )
                .toList()
              ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));

        final rideCount = driverRides.length;
        // Only rides whose pickup time is still ahead can be bulk-reassigned —
        // the backend rejects reassigning a past ride (past_ride).
        final reassignableRides = driverRides
            .where((r) => !r.isPastPickup)
            .toList();
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

            showAdaptiveDialog(
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
                      // Conflicts were detected and shown in the dialog;
                      // "Assign anyway" must override the backend guard instead
                      // of bouncing off a 409 and re-prompting.
                      overrideScheduleConflict: conflicts.isNotEmpty,
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
              color: isHovering
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.rideAssignedBgDark
                        : AppColors.rideAssignedBg)
                  : null,
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
                            if (reassignableRides.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  showAdaptiveDialog(
                                    context: context,
                                    builder: (_) => BulkReassignDialog(
                                      fromDriverId: scheduleDay.driverId,
                                      fromDriverLabel: resolveDriverLabel(
                                        scheduleDay,
                                        driverNames,
                                      ),
                                      rides: reassignableRides,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.swap_horiz,
                                    size: 20,
                                    // errorStrong is invisible on the dark Card;
                                    // use the theme error red in dark mode.
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.rideCancelledTextDark
                                        : AppColors.errorStrong,
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
                                      driverScheduleRideLabel(
                                        ride,
                                        AppLocalizations.of(context),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Past rides are excluded: the backend
                                  // rejects reassigning them (past_ride).
                                  if (ride.status == RideStatus.assigned &&
                                      !ride.isPastPickup)
                                    GestureDetector(
                                      onTap: () => showReassignSheet(
                                        context,
                                        ride,
                                        driverNames,
                                      ),
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

/// A single driver's schedule rendered as a full-height column in the wide
/// (board) layout: a fixed header plus a scrollable list of *all* the driver's
/// rides. Shares the drop-to-assign and reassign behaviour with the card.
class _DriverScheduleColumn extends StatelessWidget {
  final ScheduleDay scheduleDay;
  final Map<String, String> driverNames;

  const _DriverScheduleColumn({
    required this.scheduleDay,
    required this.driverNames,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      buildWhen: (prev, curr) => prev.rides != curr.rides,
      builder: (context, rideState) {
        final driverRides =
            rideState.rides
                .where(
                  (r) =>
                      r.driverId == scheduleDay.driverId &&
                      r.status != RideStatus.cancelled &&
                      r.status != RideStatus.completed,
                )
                .toList()
              ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));

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

            showAdaptiveDialog(
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
                      // Conflicts were detected and shown in the dialog;
                      // "Assign anyway" must override the backend guard instead
                      // of bouncing off a 409 and re-prompting.
                      overrideScheduleConflict: conflicts.isNotEmpty,
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
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHovering
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              elevation: isHovering ? 4 : 2,
              color: isHovering
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.rideAssignedBgDark
                        : AppColors.rideAssignedBg)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: loadColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildColumnHeader(
                      context,
                      colorScheme,
                      loadColor,
                      driverRides,
                    ),
                    Container(height: 1, color: colorScheme.outlineVariant),
                    Expanded(
                      child: driverRides.isEmpty
                          ? _buildColumnEmpty(context, colorScheme, isHovering)
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              itemCount: driverRides.length,
                              itemBuilder: (context, index) {
                                return _buildRideRow(
                                  context,
                                  colorScheme,
                                  driverRides[index],
                                );
                              },
                            ),
                    ),
                    if (isHovering)
                      Padding(
                        padding: const EdgeInsets.all(8),
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

  Widget _buildColumnHeader(
    BuildContext context,
    ColorScheme colorScheme,
    Color loadColor,
    List<Ride> driverRides,
  ) {
    final rideCount = driverRides.length;
    // Only rides whose pickup time is still ahead can be bulk-reassigned —
    // the backend rejects reassigning a past ride (past_ride).
    final reassignableRides = driverRides
        .where((r) => !r.isPastPickup)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        resolveDriverLabel(scheduleDay, driverNames),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (reassignableRides.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    showAdaptiveDialog(
                      context: context,
                      builder: (_) => BulkReassignDialog(
                        fromDriverId: scheduleDay.driverId,
                        fromDriverLabel: resolveDriverLabel(
                          scheduleDay,
                          driverNames,
                        ),
                        rides: reassignableRides,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.swap_horiz,
                      size: 20,
                      // errorStrong is invisible on the dark Card; use the
                      // theme error red in dark mode.
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.rideCancelledTextDark
                          : AppColors.errorStrong,
                    ),
                  ),
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
                  style: TextStyle(
                    color: loadColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
        ],
      ),
    );
  }

  Widget _buildRideRow(
    BuildContext context,
    ColorScheme colorScheme,
    Ride ride,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_car, size: 12, color: AppColors.rideAssigned),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${DateFormat('HH:mm').format(ride.pickupDateTime)} ${ride.from.address}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Past rides are excluded: the backend rejects reassigning them
          // (past_ride).
          if (ride.status == RideStatus.assigned && !ride.isPastPickup)
            GestureDetector(
              onTap: () => showReassignSheet(context, ride, driverNames),
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
    );
  }

  Widget _buildColumnEmpty(
    BuildContext context,
    ColorScheme colorScheme,
    bool isHovering,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          isHovering ? 'Drop here to assign' : 'No rides',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

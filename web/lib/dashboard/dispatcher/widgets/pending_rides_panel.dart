import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../utils/ride_status_styles.dart';
import '../utils/conflict_detector.dart';
import '../../../widgets/common/notification_bell.dart';
import 'assignment_dialog.dart';
import 'eta_alert_card.dart';

class PendingRidesPanel extends StatefulWidget {
  final List<EtaAtRiskInfo> etaAlerts;
  final void Function(String rideId)? onDismissEtaAlert;
  final void Function(String rideId)? onReassignFromEtaAlert;

  const PendingRidesPanel({
    super.key,
    this.etaAlerts = const [],
    this.onDismissEtaAlert,
    this.onReassignFromEtaAlert,
  });

  @override
  State<PendingRidesPanel> createState() => _PendingRidesPanelState();
}

enum _SortMode { timeAsc, timeDesc, client }

enum _FilterMode { all, today, airport }

class _PendingRidesPanelState extends State<PendingRidesPanel> {
  _SortMode _sortMode = _SortMode.timeAsc;
  _FilterMode _filterMode = _FilterMode.all;
  String _searchQuery = '';
  int _tabIndex = 0; // 0 = Pending, 1 = Assigned
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    context.read<RideBloc>().add(const RideLoadPendingRequested());
    context.read<ScheduleBloc>().add(ScheduleLoadForDate(date: DateTime.now()));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  List<Ride> _applyFiltersAndSort(List<Ride> rides) {
    final statusFilter = _tabIndex == 0
        ? RideStatus.requested
        : RideStatus.assigned;
    var filtered = rides.where((r) => r.status == statusFilter).toList();

    switch (_filterMode) {
      case _FilterMode.today:
        final now = DateTime.now();
        filtered = filtered
            .where(
              (r) =>
                  r.pickupDateTime.year == now.year &&
                  r.pickupDateTime.month == now.month &&
                  r.pickupDateTime.day == now.day,
            )
            .toList();
      case _FilterMode.airport:
        filtered = filtered.where((r) => r.isAirportTransfer).toList();
      case _FilterMode.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (r) =>
                r.clientName.toLowerCase().contains(q) ||
                r.from.address.toLowerCase().contains(q) ||
                r.to.address.toLowerCase().contains(q) ||
                (r.flightNumber?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    switch (_sortMode) {
      case _SortMode.timeAsc:
        filtered.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
      case _SortMode.timeDesc:
        filtered.sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
      case _SortMode.client:
        filtered.sort((a, b) => a.clientName.compareTo(b.clientName));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideBloc, RideState>(
      listenWhen: (prev, curr) =>
          (curr.status == RideStateStatus.reassignConflict &&
              prev.status != RideStateStatus.reassignConflict) ||
          (curr.status == RideStateStatus.assignConflict &&
              prev.status != RideStateStatus.assignConflict),
      listener: (context, state) {
        if (state.hasReassignConflict) {
          _showReassignConflictDialog(
            context,
            rideId: state.conflictRideId!,
            driverId: state.conflictDriverId!,
            message: state.errorMessage,
          );
        } else if (state.hasAssignConflict) {
          _showAssignConflictDialog(
            context,
            rideId: state.conflictRideId!,
            driverId: state.conflictDriverId!,
            message: state.errorMessage,
          );
        }
      },
      child: _buildBody(),
    );
  }

  /// Shown when the backend rejects a primary assignment with a schedule
  /// conflict the client didn't detect locally. Lets the dispatcher assign
  /// anyway.
  void _showAssignConflictDialog(
    BuildContext context, {
    required String rideId,
    required String driverId,
    String? message,
  }) {
    showAdaptiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Driver is busy'),
        content: Text(
          message ??
              'The selected driver already has a ride at this time. '
                  'Assign anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<RideBloc>().add(
                RideAssignRequested(
                  rideId: rideId,
                  driverId: driverId,
                  overrideScheduleConflict: true,
                ),
              );
            },
            child: const Text('Assign anyway'),
          ),
        ],
      ),
    );
  }

  /// Shown when the backend rejects a reassignment with a schedule conflict the
  /// client didn't detect locally. Lets the dispatcher reassign anyway.
  void _showReassignConflictDialog(
    BuildContext context, {
    required String rideId,
    required String driverId,
    String? message,
  }) {
    showAdaptiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Driver is busy'),
        content: Text(
          message ??
              'The selected driver already has a ride at this time. '
                  'Reassign anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<RideBloc>().add(
                RideReassignRequested(
                  rideId: rideId,
                  newDriverId: driverId,
                  overrideScheduleConflict: true,
                ),
              );
            },
            child: const Text('Reassign anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        if (widget.etaAlerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
              vertical: AppDimensions.paddingSmall,
            ),
            child: Column(
              children: widget.etaAlerts
                  .map(
                    (a) => EtaAlertCard(
                      info: a,
                      onDismiss: () => widget.onDismissEtaAlert?.call(a.rideId),
                      onReassign: () =>
                          widget.onReassignFromEtaAlert?.call(a.rideId),
                    ),
                  )
                  .toList(),
            ),
          ),
        _buildTabBar(),
        _buildFilterBar(),
        Expanded(
          child: BlocBuilder<RideBloc, RideState>(
            buildWhen: (prev, curr) =>
                prev.rides != curr.rides || prev.isLoading != curr.isLoading,
            builder: (context, state) {
              if (state.isLoading) {
                return Center(child: CircularProgressIndicator.adaptive());
              }

              final rides = _applyFiltersAndSort(state.rides);

              if (rides.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<RideBloc>().add(
                    const RideLoadPendingRequested(),
                  );
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    final isAtRisk = widget.etaAlerts.any(
                      (a) => a.rideId == ride.id,
                    );
                    if (_tabIndex == 1) {
                      return _RideRow(
                        key: ValueKey(ride.id),
                        ride: ride,
                        isAtRisk: isAtRisk,
                        onAction: () => _showDriverSelectionSheet(
                          context,
                          ride,
                          isReassign: true,
                        ),
                        isReassign: true,
                      );
                    }
                    return Draggable<Ride>(
                      key: ValueKey(ride.id),
                      data: ride,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 280,
                          child: _RideRow(
                            ride: ride,
                            isDragging: true,
                            isAtRisk: false,
                            onAction: null,
                            isReassign: false,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _RideRow(
                          ride: ride,
                          isAtRisk: isAtRisk,
                          onAction: null,
                          isReassign: false,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () => _showDriverSelectionSheet(context, ride),
                        child: _RideRow(
                          ride: ride,
                          isAtRisk: isAtRisk,
                          onAction: () =>
                              _showDriverSelectionSheet(context, ride),
                          isReassign: false,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, state) {
        final pendingCount = state.rides
            .where((r) => r.status == RideStatus.requested)
            .length;
        final assignedCount = state.rides
            .where((r) => r.status == RideStatus.assigned)
            .length;
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(child: _buildTab(0, 'Pending', pendingCount)),
              Expanded(child: _buildTab(1, 'Assigned', assignedCount)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(int index, String label, int count) {
    final selected = _tabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.accent
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
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
                hintText: 'Search client, address...',
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
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildFilterChip('All', _FilterMode.all),
              const SizedBox(width: 6),
              _buildFilterChip('Today', _FilterMode.today),
              const SizedBox(width: 6),
              _buildFilterChip('Airport', _FilterMode.airport),
              const Spacer(),
              PopupMenuButton<_SortMode>(
                icon: Icon(
                  Icons.sort,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Sort',
                onSelected: (mode) => setState(() => _sortMode = mode),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SortMode.timeAsc,
                    child: Text(
                      'Time (earliest first)',
                      style: TextStyle(
                        fontWeight: _sortMode == _SortMode.timeAsc
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SortMode.timeDesc,
                    child: Text(
                      'Time (latest first)',
                      style: TextStyle(
                        fontWeight: _sortMode == _SortMode.timeDesc
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SortMode.client,
                    child: Text(
                      'Client name',
                      style: TextStyle(
                        fontWeight: _sortMode == _SortMode.client
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _FilterMode mode) {
    final selected = _filterMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _filterMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Builds the panel header. In mobile view this is the full-width graphite
  /// gradient banner; in the desktop split-view the top bar is handled by
  /// [DispatcherDashboard._buildSplitViewContent], so this header is a
  /// compact theme-aware panel header with an amber unassigned-count badge.
  Widget _buildHeader() {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, state) {
        final unassignedCount = state.rides
            .where((r) => r.status == RideStatus.requested)
            .length;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Pending requests',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unassignedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.rideRequestedBgDark
                                : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.rideRequestedBorder,
                            ),
                          ),
                          child: Text(
                            '$unassignedCount unassigned',
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.rideRequestedTextDark
                                  : AppColors.warningStrong,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const NotificationBell(),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => context.read<RideBloc>().add(
                    const RideLoadPendingRequested(),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDriverSelectionSheet(
    BuildContext context,
    Ride ride, {
    bool isReassign = false,
  }) {
    final scheduleState = context.read<ScheduleBloc>().state;
    final rideState = context.read<RideBloc>().state;
    final authBloc = context.read<AuthBloc>();

    final scheduledDriverIds = scheduleState.scheduleDays
        .where((d) => d.status != ScheduleDayStatus.cancelled)
        .map((d) => d.driverId)
        .toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DriverSelectionSheet(
        ride: ride,
        rideState: rideState,
        scheduledDriverIds: scheduledDriverIds,
        userService: UserService(apiClient: authBloc.apiClient),
        isReassign: isReassign,
        onAssign: (driverId, driverLabel, conflicts) {
          Navigator.pop(ctx);
          showAdaptiveDialog(
            context: context,
            builder: (_) => AssignmentDialog(
              ride: ride,
              driverLabel: driverLabel,
              driverId: driverId,
              conflicts: conflicts,
              onConfirm: () {
                if (isReassign) {
                  // If the dispatcher already saw locally-detected conflicts and
                  // confirmed ("Assign anyway"), tell the backend to override so
                  // it doesn't reject the reassignment.
                  context.read<RideBloc>().add(
                    RideReassignRequested(
                      rideId: ride.id,
                      newDriverId: driverId,
                      overrideScheduleConflict: conflicts.isNotEmpty,
                    ),
                  );
                } else {
                  // Same as the reassign branch: if the dispatcher already saw
                  // locally-detected conflicts and confirmed ("Assign anyway"),
                  // tell the backend to override so it doesn't reject the
                  // assignment with a 409.
                  context.read<RideBloc>().add(
                    RideAssignRequested(
                      rideId: ride.id,
                      driverId: driverId,
                      overrideScheduleConflict: conflicts.isNotEmpty,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isPending = _tabIndex == 0;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
          const SizedBox(height: 12),
          Text(
            isPending ? 'No pending rides' : 'No assigned rides',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPending
                ? 'All rides have been assigned'
                : 'No rides currently assigned to drivers',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Redesigned Ride Row (replaces _PendingRideCard + _AssignedRideCard) ───

class _RideRow extends StatelessWidget {
  final Ride ride;
  final bool isAtRisk;
  final VoidCallback? onAction;
  final bool isReassign;
  final bool isDragging;

  const _RideRow({
    super.key,
    required this.ride,
    required this.isAtRisk,
    required this.onAction,
    required this.isReassign,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = brightness == Brightness.dark;

    // At-risk rows get a subtle red tint
    final rowBg = isAtRisk
        ? AppColors.error.withValues(alpha: isDark ? 0.08 : 0.04)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isAtRisk
              ? AppColors.errorBorder
              : (isDark ? AppColors.borderDark : AppColors.borderPrimary),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: status badge + VIP · price
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RideStatusStyles.createStatusBadge(
                  ride.status,
                  context: context,
                  fontSize: 10,
                  iconSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                ),
                if (ride.isVipRide) ...[const SizedBox(width: 6), _vipChip()],
                const Spacer(),
                if (ride.price != null)
                  Text(
                    '€${ride.price!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Address block: full From / To, no truncation
            _addressRow(
              context,
              icon: Icons.trip_origin,
              iconColor: colorScheme.onSurfaceVariant,
              address: ride.from.address,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.5),
              child: SizedBox(
                height: 14,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderPrimary,
                ),
              ),
            ),
            _addressRow(
              context,
              icon: Icons.location_on,
              iconColor: colorScheme.primary,
              address: ride.to.address,
            ),
            const SizedBox(height: 12),
            // Meta: time · client [· driver] [· ETA]
            Text(
              _buildMetaLine(),
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Airport / flight info
            if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ride.flightIconData != null) ...[
                    Icon(
                      ride.flightIconData,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      ride.fullFlightInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Action button (full width)
            if (onAction != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A single address line with a leading icon and full, untruncated text.
  Widget _addressRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _vipChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 11, color: AppColors.warning),
          SizedBox(width: 3),
          Text(
            'VIP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isReassign) {
      // Soft-red "Reassign" button
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.errorStrong,
            side: const BorderSide(color: AppColors.errorBorder),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Reassign'),
        ),
      );
    } else {
      // Graphite "Assign" button — theme-aware so it stays visible in dark
      // (AppColors.primary == surfaceDark, so the button vanished on the card).
      final colorScheme = Theme.of(context).colorScheme;
      return SizedBox(
        height: 32,
        child: FilledButton(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Assign'),
        ),
      );
    }
  }

  String _buildMetaLine() {
    final time = DateFormat('dd.MM HH:mm').format(ride.pickupDateTime);
    final parts = [time, ride.clientName];
    if (ride.driverName != null) parts.add(ride.driverName!);
    if (ride.etaMinutes != null) parts.add('${ride.etaMinutes} min');
    if (ride.driverDistanceMeters != null) {
      final km = ride.driverDistanceMeters! / 1000;
      parts.add('${km.toStringAsFixed(1)} km');
    }
    return parts.join(' · ');
  }
}

// ─── Driver Selection Sheet (unchanged business logic, restyled header) ────

class _DriverSelectionSheet extends StatefulWidget {
  final Ride ride;
  final RideState rideState;
  final Set<String> scheduledDriverIds;
  final UserService userService;
  final bool isReassign;
  final void Function(String driverId, String driverLabel, List<Ride> conflicts)
  onAssign;

  const _DriverSelectionSheet({
    required this.ride,
    required this.rideState,
    required this.scheduledDriverIds,
    required this.userService,
    required this.onAssign,
    this.isReassign = false,
  });

  @override
  State<_DriverSelectionSheet> createState() => _DriverSelectionSheetState();
}

class _DriverSelectionSheetState extends State<_DriverSelectionSheet> {
  List<Person>? _drivers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await widget.userService.getDrivers();
      if (mounted) setState(() => _drivers = drivers);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withAlpha(140),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isReassign ? 'Reassign Driver' : 'Select Driver',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.ride.clientName} — ${DateFormat('dd.MM HH:mm').format(widget.ride.pickupDateTime)}',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withAlpha(180),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(scrollController)),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }
    if (_drivers == null) {
      return Center(child: CircularProgressIndicator.adaptive());
    }
    if (_drivers!.isEmpty) {
      return const Center(child: Text('No drivers found'));
    }

    final drivers = List<Person>.from(_drivers!)
      ..sort((a, b) {
        final aScheduled = widget.scheduledDriverIds.contains(a.id) ? 0 : 1;
        final bScheduled = widget.scheduledDriverIds.contains(b.id) ? 0 : 1;
        if (aScheduled != bScheduled) return aScheduled - bScheduled;
        return a.name.compareTo(b.name);
      });

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      itemBuilder: (_, index) {
        final driver = drivers[index];
        final isScheduled = widget.scheduledDriverIds.contains(driver.id);
        final driverRides = widget.rideState.rides
            .where(
              (r) =>
                  r.driverId == driver.id &&
                  r.status != RideStatus.cancelled &&
                  r.status != RideStatus.completed,
            )
            .toList();
        final conflicts = ConflictDetector.findConflicts(
          widget.ride,
          driverRides,
        );
        final rideCount = driverRides.length;
        final loadColor = rideCount == 0
            ? AppColors.success
            : rideCount <= 2
            ? AppColors.warning
            : AppColors.error;

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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    driver.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isScheduled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.success.withAlpha(80),
                      ),
                    ),
                    child: const Text(
                      'Scheduled',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rideCount ride${rideCount == 1 ? '' : 's'} assigned',
                  style: TextStyle(color: loadColor, fontSize: 12),
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
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => widget.onAssign(driver.id, driver.name, conflicts),
          ),
        );
      },
    );
  }
}

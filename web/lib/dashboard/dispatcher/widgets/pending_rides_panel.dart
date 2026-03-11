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

class PendingRidesPanel extends StatefulWidget {
  const PendingRidesPanel({super.key});

  @override
  State<PendingRidesPanel> createState() => _PendingRidesPanelState();
}

enum _SortMode { timeAsc, timeDesc, client }
enum _FilterMode { all, today, airport }

class _PendingRidesPanelState extends State<PendingRidesPanel> {
  _SortMode _sortMode = _SortMode.timeAsc;
  _FilterMode _filterMode = _FilterMode.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<RideBloc>().add(const RideLoadPendingRequested());
  }

  List<Ride> _applyFiltersAndSort(List<Ride> rides) {
    var filtered = rides.where((r) => r.status == RideStatus.requested).toList();

    // Apply filter
    switch (_filterMode) {
      case _FilterMode.today:
        final now = DateTime.now();
        filtered = filtered.where((r) =>
          r.pickupDateTime.year == now.year &&
          r.pickupDateTime.month == now.month &&
          r.pickupDateTime.day == now.day
        ).toList();
      case _FilterMode.airport:
        filtered = filtered.where((r) => r.isAirportTransfer).toList();
      case _FilterMode.all:
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) =>
        r.clientName.toLowerCase().contains(q) ||
        r.from.address.toLowerCase().contains(q) ||
        r.to.address.toLowerCase().contains(q) ||
        (r.flightNumber?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    // Apply sort
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
    return Column(
      children: [
        _buildHeader(),
        _buildFilterBar(),
        Expanded(
          child: BlocBuilder<RideBloc, RideState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final pendingRides = _applyFiltersAndSort(state.rides);

              if (pendingRides.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<RideBloc>().add(const RideLoadPendingRequested());
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  itemCount: pendingRides.length,
                  itemBuilder: (context, index) {
                    final ride = pendingRides[index];
                    return Draggable<Ride>(
                      data: ride,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 280,
                          child: _PendingRideCard(ride: ride, isDragging: true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _PendingRideCard(ride: ride),
                      ),
                      child: GestureDetector(
                        onTap: () => _showDriverSelectionSheet(context, ride),
                        child: _PendingRideCard(ride: ride),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          // Search
          SizedBox(
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search client, address...',
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
          // Filter chips + sort
          Row(
            children: [
              _buildFilterChip('All', _FilterMode.all),
              const SizedBox(width: 6),
              _buildFilterChip('Today', _FilterMode.today),
              const SizedBox(width: 6),
              _buildFilterChip('Airport', _FilterMode.airport),
              const Spacer(),
              PopupMenuButton<_SortMode>(
                icon: Icon(Icons.sort, size: 20, color: Colors.grey.shade700),
                tooltip: 'Sort',
                onSelected: (mode) => setState(() => _sortMode = mode),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _SortMode.timeAsc, child: Text('Time (earliest first)', style: TextStyle(fontWeight: _sortMode == _SortMode.timeAsc ? FontWeight.bold : FontWeight.normal))),
                  PopupMenuItem(value: _SortMode.timeDesc, child: Text('Time (latest first)', style: TextStyle(fontWeight: _sortMode == _SortMode.timeDesc ? FontWeight.bold : FontWeight.normal))),
                  PopupMenuItem(value: _SortMode.client, child: Text('Client name', style: TextStyle(fontWeight: _sortMode == _SortMode.client ? FontWeight.bold : FontWeight.normal))),
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
    return GestureDetector(
      onTap: () => setState(() => _filterMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey.shade100,
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
        child: BlocBuilder<RideBloc, RideState>(
          builder: (context, state) {
            final count = state.rides
                .where((r) => r.status == RideStatus.requested)
                .length;
            return Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Rides',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$count ride${count == 1 ? '' : 's'} awaiting assignment',
                        style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                  onPressed: () => context.read<RideBloc>().add(const RideLoadPendingRequested()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDriverSelectionSheet(BuildContext context, Ride ride) {
    final scheduleState = context.read<ScheduleBloc>().state;
    final rideState = context.read<RideBloc>().state;

    final availableDrivers = scheduleState.scheduleDays
        .where((d) => d.status != ScheduleDayStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (availableDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drivers scheduled. Load schedules first.')),
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
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
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
                    'Select Driver',
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
                itemCount: availableDrivers.length,
                itemBuilder: (_, index) {
                  final schedule = availableDrivers[index];
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
                          Text('${schedule.startTime} — ${schedule.endTime}'),
                          Text(
                            '$rideCount ride${rideCount == 1 ? '' : 's'} assigned',
                            style: TextStyle(color: loadColor, fontSize: 12),
                          ),
                          if (conflicts.isNotEmpty)
                            Text(
                              '${conflicts.length} time conflict${conflicts.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => AssignmentDialog(
                            ride: ride,
                            driverLabel: driverLabel,
                            driverId: schedule.driverId,
                            conflicts: conflicts,
                            onConfirm: () {
                              context.read<RideBloc>().add(RideAssignRequested(
                                rideId: ride.id,
                                driverId: schedule.driverId,
                              ));
                            },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text(
            'No pending rides',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            'All rides have been assigned',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _PendingRideCard extends StatelessWidget {
  final Ride ride;
  final bool isDragging;

  const _PendingRideCard({required this.ride, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDragging ? 8 : 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.rideRequested),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd.MM HH:mm').format(ride.pickupDateTime),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.rideRequestedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.rideRequestedBorder),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(color: AppColors.rideRequestedText, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, ride.clientName),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.location_on, ride.from.address),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.flag, ride.to.address),
            if (ride.isAirportTransfer && ride.flightNumber != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                ride.isArrival ? Icons.flight_land : Icons.flight_takeoff,
                ride.flightNumber!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

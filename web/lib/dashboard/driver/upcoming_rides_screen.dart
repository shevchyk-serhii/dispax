import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/navigation_helper.dart';
import '../../constants/app_colors.dart';

class UpcomingRidesScreen extends StatelessWidget {
  const UpcomingRidesScreen({super.key});

  void loadUpcomingRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  void refreshRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideRefreshRequested(user: authState.user!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.event_note, color: Colors.white),
            SizedBox(width: 8),
            Text('Upcoming Rides'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshRides(context),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {
          if (state.hasError) {
            NavigationHelper.showSnackBar(
              context,
              state.errorMessage!,
              isError: true,
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade600, Colors.grey.shade50],
              stops: const [0.0, 0.2],
            ),
          ),
          child: BlocBuilder<RideBloc, RideState>(
            builder: (context, rideState) {
              return buildBody(context, rideState);
            },
          ),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context, RideState rideState) {

    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadUpcomingRides(context),
      );
    }

    if (rideState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        title: 'Failed to load upcoming rides',
        message: rideState.errorMessage!,
        onRetry: () => refreshRides(context),
      );
    }

    final upcomingRides = getUpcomingRides(rideState.rides);
    final groupedRides = groupRidesByDate(upcomingRides);

    if (upcomingRides.isEmpty) {
      return buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: buildUpcomingStats(upcomingRides)),
          ...groupedRides.entries.map((entry) {
            return SliverToBoxAdapter(
              child: buildDateGroup(entry.key, entry.value),
            );
          }),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 24),
          Text(
            'No upcoming rides',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All caught up for now!',
            style: TextStyle(fontSize: 16, color: Colors.blue.shade500),
          ),
        ],
      ),
    );
  }

  Widget buildUpcomingStats(List<Ride> upcomingRides) {
    final next7Days = upcomingRides.where((ride) {
      final difference = ride.pickupDateTime.difference(DateTime.now()).inDays;
      return difference <= 7;
    }).length;

    final thisWeek = upcomingRides.where((ride) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      return ride.pickupDateTime.isAfter(startOfWeek) &&
          ride.pickupDateTime.isBefore(endOfWeek);
    }).length;

    final thisMonth = upcomingRides.where((ride) {
      final now = DateTime.now();
      return ride.pickupDateTime.year == now.year &&
          ride.pickupDateTime.month == now.month;
    }).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem(
                icon: Icons.today,
                count: next7Days,
                label: 'Next 7 Days',
                color: Colors.orange,
              ),
              buildStatItem(
                icon: Icons.view_week,
                count: thisWeek,
                label: 'This Week',
                color: Colors.blue,
              ),
              buildStatItem(
                icon: Icons.calendar_month,
                count: thisMonth,
                label: 'This Month',
                color: Colors.green,
              ),
              buildStatItem(
                icon: Icons.event,
                count: upcomingRides.length,
                label: 'Total',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget buildDateGroup(String dateKey, List<Ride> rides) {
    final date = DateTime.parse(dateKey);
    final isToday = isSameDay(date, DateTime.now());
    final isTomorrow = isSameDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat.yMMMEd().format(date);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          margin: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isToday || isTomorrow
                      ? Colors.blue.shade600
                      : Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rides.length} rides',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: rides.map((ride) => buildUpcomingRideCard(ride)).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildUpcomingRideCard(Ride ride) {
    final statusColor = getStatusColor(ride.status);
    final daysUntilRide = ride.pickupDateTime.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withAlpha(51), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.Hm().format(ride.pickupDateTime),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      if (daysUntilRide <= 1)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Soon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      getStatusText(ride.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              buildCompactRideInfo(Icons.person, ride.clientName),
              const SizedBox(height: 6),
              buildCompactRideInfo(Icons.location_on, ride.from.address),
              const SizedBox(height: 6),
              buildCompactRideInfo(Icons.flag, ride.to.address),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCompactRideInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Ride> getUpcomingRides(List<Ride> rides) {
    final now = DateTime.now();
    return rides.where((ride) {
      return ride.pickupDateTime.isAfter(now) &&
          (ride.status == RideStatus.assigned ||
              ride.status == RideStatus.requested);
    }).toList()..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
  }

  Map<String, List<Ride>> groupRidesByDate(List<Ride> rides) {
    final grouped = <String, List<Ride>>{};

    for (final ride in rides) {
      final dateKey =
          '${ride.pickupDateTime.year}-${ride.pickupDateTime.month.toString().padLeft(2, '0')}-${ride.pickupDateTime.day.toString().padLeft(2, '0')}';

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(ride);
    }

    return grouped;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequested;
      case RideStatus.assigned:
        return AppColors.rideAssigned;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
    }
  }

  String getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'REQUESTED';
      case RideStatus.assigned:
        return 'ASSIGNED';
      case RideStatus.inProgress:
        return 'IN PROGRESS';
      case RideStatus.completed:
        return 'COMPLETED';
      case RideStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

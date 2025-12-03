import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';
import '../../models/ride.dart';
import '../../widgets/widgets.dart';
import '../../utils/navigation_helper.dart';

class TodayRidesScreen extends StatelessWidget {
  const TodayRidesScreen({super.key});

  void loadTodayRides(BuildContext context) {
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
        title: Row(
          children: [
            const Icon(Icons.today, color: Colors.white),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat.yMMMEd().format(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
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
    // Load rides on first build if not loaded yet
    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadTodayRides(context),
      );
    }

    if (rideState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        title: 'Failed to load today\'s rides',
        message: rideState.errorMessage!,
        onRetry: () => refreshRides(context),
      );
    }

    final todayRides = getTodayRides(rideState.rides);

    if (todayRides.isEmpty) {
      return buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: buildTodayStats(todayRides)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final ride = todayRides[index];
                return buildTodayRideCard(
                  context,
                  ride,
                  index == todayRides.length - 1,
                );
              }, childCount: todayRides.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.free_breakfast, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 24),
          Text(
            'No rides today!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enjoy your free day',
            style: TextStyle(fontSize: 16, color: Colors.blue.shade500),
          ),
        ],
      ),
    );
  }

  Widget buildTodayStats(List<Ride> todayRides) {
    final completedRides = todayRides
        .where((r) => r.status == RideStatus.completed)
        .length;
    final upcomingRides = todayRides
        .where((r) => r.status == RideStatus.assigned)
        .length;
    final inProgressRides = todayRides
        .where((r) => r.status == RideStatus.inProgress)
        .length;

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
            'Today\'s Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem(
                icon: Icons.event,
                count: todayRides.length,
                label: 'Total',
                color: Colors.blue,
              ),
              buildStatItem(
                icon: Icons.play_arrow,
                count: upcomingRides,
                label: 'Upcoming',
                color: Colors.orange,
              ),
              buildStatItem(
                icon: Icons.directions_car,
                count: inProgressRides,
                label: 'Active',
                color: Colors.green,
              ),
              buildStatItem(
                icon: Icons.check_circle,
                count: completedRides,
                label: 'Done',
                color: Colors.grey,
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget buildTodayRideCard(BuildContext context, Ride ride, bool isLast) {
    final statusColor = getStatusColor(ride.status);
    final isUpcoming = ride.pickupDateTime.isAfter(DateTime.now());
    final timeUntilRide = ride.pickupDateTime.difference(DateTime.now());

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withAlpha(77), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: statusColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.Hm().format(ride.pickupDateTime),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (isUpcoming && timeUntilRide.inHours < 2)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Soon',
                              style: const TextStyle(
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        getStatusText(ride.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    buildRideInfo(Icons.person, ride.clientName, 'Client'),
                    const SizedBox(height: 12),
                    buildRideInfo(
                      Icons.location_on,
                      ride.from.address,
                      'Pickup',
                    ),
                    const SizedBox(height: 12),
                    buildRideInfo(Icons.flag, ride.to.address, 'Destination'),
                    const SizedBox(height: 16),
                    buildQuickActions(ride),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRideInfo(IconData icon, String text, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildQuickActions(Ride ride) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {}, // TODO: Implement call client
              icon: const Icon(Icons.phone),
              color: Colors.green,
              tooltip: 'Call Client',
            ),
            IconButton(
              onPressed: () {}, // TODO: Implement navigation
              icon: const Icon(Icons.navigation),
              color: Colors.blue,
              tooltip: 'Navigate',
            ),
            IconButton(
              onPressed: () {}, // TODO: Implement message client
              icon: const Icon(Icons.message),
              color: Colors.orange,
              tooltip: 'Message',
            ),
          ],
        ),
        if (ride.status == RideStatus.assigned)
          ElevatedButton.icon(
            onPressed: () {}, // TODO: Implement start ride
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start Ride'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          )
        else if (ride.status == RideStatus.inProgress)
          ElevatedButton.icon(
            onPressed: () {}, // TODO: Implement complete ride
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  List<Ride> getTodayRides(List<Ride> rides) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return rides.where((ride) {
      return ride.pickupDateTime.isAfter(todayStart) &&
          ride.pickupDateTime.isBefore(todayEnd);
    }).toList()..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
  }

  Color getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Colors.orange;
      case RideStatus.assigned:
        return Colors.blue;
      case RideStatus.inProgress:
        return Colors.green;
      case RideStatus.completed:
        return Colors.grey;
      case RideStatus.cancelled:
        return Colors.red;
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

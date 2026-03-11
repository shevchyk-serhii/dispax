import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/driver_management/widgets/widgets.dart';
import '../../modules/core/widgets/widgets.dart';
import '../../modules/core/navigation_helper.dart';

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
          SliverToBoxAdapter(child: TodayStatsCard(todayRides: todayRides)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final ride = todayRides[index];
                return TodayRideCard(
                  ride: ride,
                  isLast: index == todayRides.length - 1,

                  onCallClient: () => _handleCallClient(context, ride),
                  onStartRide: () => _handleStartRide(context, ride),
                  onCompleteRide: () => _handleCompleteRide(context, ride),
                );
              }, childCount: todayRides.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return const EmptyRidesState();
  }

  void _handleCallClient(BuildContext context, Ride ride) {
    final phone = ride.client.phone;
    if (phone == null || phone.isEmpty) {
      NavigationHelper.showSnackBar(context, 'No phone number available', isError: true);
      return;
    }
    _showContactOptions(context, phone);
  }

  void _showContactOptions(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
              title: const Text('SMS'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('sms:$phone'));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleStartRide(BuildContext context, Ride ride) {
    context.read<RideBloc>().add(RideStatusUpdateRequested(
      rideId: ride.id,
      status: RideStatus.inProgress,
    ));
    NavigationHelper.showSnackBar(context, 'Ride started');
  }

  void _handleCompleteRide(BuildContext context, Ride ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Ride'),
        content: Text('Mark ride from ${ride.from.address} to ${ride.to.address} as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RideBloc>().add(RideStatusUpdateRequested(
                rideId: ride.id,
                status: RideStatus.completed,
              ));
              NavigationHelper.showSnackBar(context, 'Ride completed');
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  List<Ride> getTodayRides(List<Ride> rides) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return rides.where((ride) {
      return ride.pickupDateTime.isAfter(todayStart) &&
          ride.pickupDateTime.isBefore(todayEnd) &&
          ride.status != RideStatus.completed &&
          ride.status != RideStatus.cancelled;
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

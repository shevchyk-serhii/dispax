import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../models/ride.dart';
import '../../widgets/widgets.dart';
import '../../utils/date_utils.dart';
import '../../screens/flight_screen.dart';

class ClientDashboard extends StatelessWidget {
  const ClientDashboard({super.key});

  static final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return IndexedStack(
            index: selectedIndex,
            children: const [
              MyRidesTab(),
              RideStatusTab(),
              FlightScreen(),
              ProfileTab(),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              selectedIndexNotifier.value = index;
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'My Rides',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on),
                label: 'Current Ride',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.flight),
                label: 'Flights',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyRidesTab extends StatelessWidget {
  const MyRidesTab({super.key});

  void loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        // Load rides on first build if not loaded yet
        if (rideState.status == RideStateStatus.initial) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => loadRides(context),
          );
        }

        if (rideState.isLoading) {
          return const LoadingWidget();
        }

        if (rideState.hasError && rideState.rides.isEmpty) {
          return ErrorDisplayWidget(
            title: 'Failed to load rides',
            message: rideState.errorMessage!,
            onRetry: () => loadRides(context),
          );
        }

        if (rideState.isEmpty) {
          return const EmptyStateWidget(
            message: 'You have no rides booked yet',
            icon: Icons.history,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => loadRides(context),
          child: ListView.builder(
            itemCount: rideState.rides.length,
            itemBuilder: (context, index) {
              final ride = rideState.rides[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: getStatusColor(ride.status),
                    child: Icon(
                      getStatusIcon(ride.status),
                      color: Colors.white,
                    ),
                  ),
                  title: Text('${ride.from.address} → ${ride.to.address}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${ride.statusDisplayName}'),
                      Text(
                        'Pickup: ${AppDateUtils.formatDateTime(ride.pickupDateTime)}',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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

  IconData getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Icons.schedule;
      case RideStatus.assigned:
        return Icons.assignment;
      case RideStatus.inProgress:
        return Icons.directions_car;
      case RideStatus.completed:
        return Icons.check;
      case RideStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class RideStatusTab extends StatelessWidget {
  const RideStatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Current Ride',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Information about current ride and driver location',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Client Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Personal information and account settings',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

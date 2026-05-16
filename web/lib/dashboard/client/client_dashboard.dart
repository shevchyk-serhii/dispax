import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/create_ride_screen.dart';

import '../../screens/simple_map_screen.dart';
import '../../constants/app_colors.dart';
import 'client_ride_history_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.clientColor,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_outlined),
            activeIcon: Icon(Icons.list),
            label: 'Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return const MyRidesTab();
      case 1:
        return const ClientRideHistoryScreen();
      case 2:
        return CreateRideScreen(rideBloc: _rideBloc);
      case 3:
        return const SimpleMapScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const MyRidesTab();
    }
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
        if (rideState.status == RideStateStatus.initial) {
          final authState = context.read<AuthBloc>().state;
          if (authState.user != null) {
             context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
          }
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

        final activeRides = rideState.rides.where((ride) =>
          ride.status != RideStatus.completed &&
          ride.status != RideStatus.cancelled
        ).toList();

        if (activeRides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('You have no active rides', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                const Text('Use "Book" tab to create one', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => loadRides(context),
          child: ListView.builder(
            itemCount: activeRides.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final airportRides = activeRides
                    .where((ride) => ride.isAirportTransfer &&
                           (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress))
                    .toList();

                if (airportRides.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: airportRides.map((ride) => AirportEntryTimer(
                    ride: ride,
                    onEntryTimeReached: () {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Departure time reached for flight ${ride.fullFlightInfo}')),
                      );
                    },
                  )).toList(),
                );
              }

              final rideIndex = index - 1;
              final ride = activeRides[rideIndex];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RideDetailsScreen(
                          ride: ride,
                          isClientView: true,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: RideStatusStyles.getStatusColor(ride.status),
                    child: Icon(RideStatusStyles.getStatusIcon(ride.status), color: Colors.white, size: 18),
                  ),
                  title: Text('${ride.from.address} → ${ride.to.address}'),
                  subtitle: Text(AppDateUtils.formatDateTime(ride.pickupDateTime)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
        );
      },
    );
  }

}

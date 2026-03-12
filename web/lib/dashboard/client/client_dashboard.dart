import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/create_ride_screen.dart';
import 'dart:io';

import '../../screens/simple_map_screen.dart';
import '../../screens/android_map_screen.dart';
import '../../constants/app_colors.dart';
import 'client_ride_history_screen.dart';

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
            children: [
              const MyRidesTab(),
              const ClientRideHistoryScreen(),
              const CreateRideScreen(),
              Platform.isAndroid ? const AndroidMapScreen() : const SimpleMapScreen(),
              const SettingsScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return BottomNavigationBar(
            currentIndex: selectedIndex,
            selectedItemColor: AppColors.clientColor,
            onTap: (index) {
              selectedIndexNotifier.value = index;
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

  void _onAirportEntryTimeReached(BuildContext context, Ride ride) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Your driver should now depart to the airport for flight ${ride.fullFlightInfo}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.clientColor,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RideDetailsScreen(
                  ride: ride,
                  isClientView: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {

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
                ElevatedButton.icon(
                  onPressed: () => ClientDashboard.selectedIndexNotifier.value = 2,
                  icon: const Icon(Icons.add),
                  label: const Text('Book a Ride'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clientColor,
                    foregroundColor: Colors.white,
                  ),
                ),
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
                    onEntryTimeReached: () => _onAirportEntryTimeReached(context, ride),
                  )).toList(),
                );
              }

              final rideIndex = index - 1;
              final ride = activeRides[rideIndex];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: getStatusColor(ride.status),
                              radius: 20,
                              child: Icon(
                                getStatusIcon(ride.status),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${ride.from.address} → ${ride.to.address}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pickup: ${AppDateUtils.formatDateTime(ride.pickupDateTime)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: getStatusColor(ride.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: getStatusColor(ride.status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                ride.statusDisplayName,
                                style: TextStyle(
                                  color: getStatusColor(ride.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (ride.driverName != null &&
                            (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress)) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.driverColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.driverColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person, color: AppColors.driverColor, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver: ${ride.driverName}',
                                  style: TextStyle(fontSize: 12, color: AppColors.driverColor, fontWeight: FontWeight.w500),
                                ),
                                if (ride.driverApproaching) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Approaching${ride.driverDistanceMeters != null ? ' (${(ride.driverDistanceMeters! / 1000).toStringAsFixed(1)} km)' : ''}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flight,
                                  color: Colors.blue[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ride.fullFlightInfo,
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
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

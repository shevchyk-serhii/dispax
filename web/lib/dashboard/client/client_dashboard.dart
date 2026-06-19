import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/create_ride_screen.dart';

import '../../screens/client_map_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/lucide_compat.dart';
import '../../utils/ride_status_styles.dart';
import 'client_ride_history_screen.dart';
import '../../widgets/common/cancel_ride_dialog.dart';
import '../../widgets/common/responsive_scaffold.dart';
import '../../modules/ride_management/services/ride_service.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;
  final CreateRideFormBloc _createRideFormBloc = CreateRideFormBloc();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  void dispose() {
    _createRideFormBloc.close();
    super.dispose();
  }

  Future<bool> _confirmLeaveCreateRide(BuildContext context) async {
    if (!_createRideFormBloc.state.isModified) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved ride details. If you leave, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (result == true) {
      _createRideFormBloc.add(FormCleared());
    }
    return result ?? false;
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_outlined),
      selectedIcon: Icon(Icons.list),
      label: 'Rides',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_circle_outline),
      selectedIcon: Icon(Icons.add_circle),
      label: 'Book',
    ),
    NavigationDestination(
      icon: Icon(LucideCompat.map),
      selectedIcon: Icon(LucideCompat.map),
      label: 'Map',
    ),
    NavigationDestination(
      icon: Icon(LucideCompat.settings),
      selectedIcon: Icon(LucideCompat.settings),
      label: 'Settings',
    ),
  ];

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return MyRidesTab(onOpenMap: () => setState(() => _selectedIndex = 3));
      case 1:
        return const ClientRideHistoryScreen();
      case 2:
        return CreateRideScreen(
          rideBloc: _rideBloc,
          formBloc: _createRideFormBloc,
          onCreated: () {
            context.read<RideBloc>().add(
              RideLoadRequested(user: context.read<AuthBloc>().state.user!),
            );
            setState(() => _selectedIndex = 0);
          },
        );
      case 3:
        return const ClientMapScreen();
      case 4:
        return const SettingsScreen();
      default:
        return MyRidesTab(onOpenMap: () => setState(() => _selectedIndex = 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) async {
        if (_selectedIndex == 2 && index != 2) {
          final canLeave = await _confirmLeaveCreateRide(context);
          if (!canLeave) return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      body: _buildCurrentTab(),
    );
  }
}

class MyRidesTab extends StatelessWidget {
  final VoidCallback onOpenMap;

  const MyRidesTab({super.key, required this.onOpenMap});

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
            context.read<RideBloc>().add(
              RideLoadRequested(user: authState.user!),
            );
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

        final activeRides = rideState.rides
            .where(
              (ride) =>
                  ride.status != RideStatus.completed &&
                  ride.status != RideStatus.cancelled,
            )
            .toList();

        if (activeRides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available,
                  size: 56,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'You have no active rides',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Use "Book" tab to create one',
                  style: TextStyle(fontSize: 12),
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
                    .where(
                      (ride) =>
                          ride.isAirportTransfer &&
                          (ride.status == RideStatus.assigned ||
                              ride.status == RideStatus.inProgress),
                    )
                    .toList();

                if (airportRides.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: airportRides
                      .map(
                        (ride) => AirportEntryTimer(
                          ride: ride,
                          onEntryTimeReached: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Departure time reached for flight ${ride.fullFlightInfo}',
                                ),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                );
              }

              final rideIndex = index - 1;
              final ride = activeRides[rideIndex];
              final isTracking =
                  ride.status == RideStatus.inProgress ||
                  ride.status == RideStatus.assigned;
              final canCancel =
                  ride.status == RideStatus.requested ||
                  ride.status == RideStatus.assigned;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
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
                        backgroundColor: RideStatusStyles.getStatusColor(
                          ride.status,
                        ),
                        child: Icon(
                          RideStatusStyles.getStatusIcon(ride.status),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text('${ride.from.address} → ${ride.to.address}'),
                      subtitle: Text(
                        AppDateUtils.formatDateTime(ride.pickupDateTime),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    if (isTracking || canCancel)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            if (isTracking)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: onOpenMap,
                                  icon: const Icon(Icons.location_on, size: 16),
                                  label: const Text('Track driver'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.clientColor,
                                  ),
                                ),
                              ),
                            if (isTracking && canCancel)
                              const SizedBox(width: 8),
                            if (canCancel)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelRide(context, ride),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Cancel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _cancelRide(BuildContext context, Ride ride) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => const CancelRideDialog(isDispatcher: false),
    );
    if (result != null && context.mounted) {
      final rideService = RideService(
        apiClient: context.read<AuthBloc>().apiClient,
      );
      try {
        await rideService.cancelRide(ride.id, result['reason'] as String);
        if (context.mounted) {
          context.read<RideBloc>().add(
            RideLoadRequested(user: context.read<AuthBloc>().state.user!),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to cancel ride: $e')));
        }
      }
    }
  }
}

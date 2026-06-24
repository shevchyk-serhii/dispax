import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../screens/settings_screen.dart';

import '../../screens/client_map_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/lucide_compat.dart';
import '../../utils/ride_status_styles.dart';
import 'client_ride_history_screen.dart';
import 'client_home_screen.dart';
import 'client_book_screen.dart';
import '../../widgets/common/cancel_ride_dialog.dart';
import '../../modules/core/models/person.dart';
import '../../widgets/common/responsive_scaffold.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../../modules/ride_management/services/client_address_service.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;
  final CreateRideFormBloc _createRideFormBloc = CreateRideFormBloc();
  late SavedPlacesBloc _savedPlacesBloc;
  bool _savedPlacesBlocCreated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
    // didChangeDependencies fires on every ancestor InheritedWidget change
    // (auth/theme/MediaQuery), so guard the bloc creation to run exactly once —
    // otherwise each call leaks an unclosed SavedPlacesBloc.
    if (!_savedPlacesBlocCreated) {
      _savedPlacesBlocCreated = true;
      final user = context.read<AuthBloc>().state.user;
      _savedPlacesBloc = SavedPlacesBloc(
        addressService: ClientAddressService(
          apiClient: context.read<AuthBloc>().apiClient,
        ),
      );
      if (user != null) {
        _savedPlacesBloc.add(SavedPlacesLoadRequested(user.id));
      }
    }
  }

  @override
  void dispose() {
    _createRideFormBloc.close();
    _savedPlacesBloc.close();
    super.dispose();
  }

  Future<bool> _confirmLeaveCreateRide(BuildContext context) async {
    if (!_createRideFormBloc.state.isModified) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.stay),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (result == true) {
      _createRideFormBloc.add(FormCleared());
    }
    return result ?? false;
  }

  List<NavigationDestination> _buildDestinations(AppLocalizations l10n) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.homeTab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.list_outlined),
        selectedIcon: const Icon(Icons.list),
        label: l10n.ridesTab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        selectedIcon: const Icon(Icons.add_circle),
        label: l10n.bookLabel,
      ),
      NavigationDestination(
        icon: const Icon(LucideCompat.map),
        selectedIcon: const Icon(LucideCompat.map),
        label: l10n.map,
      ),
      NavigationDestination(
        icon: const Icon(LucideCompat.settings),
        selectedIcon: const Icon(LucideCompat.settings),
        label: l10n.settings,
      ),
    ];
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return BlocProvider.value(
          value: _savedPlacesBloc,
          child: ClientHomeScreen(
            onBookTap: () => setState(() => _selectedIndex = 2),
          ),
        );
      case 1:
        return const ClientRideHistoryScreen();
      case 2:
        return BlocProvider.value(
          value: _savedPlacesBloc,
          child: ClientBookScreen(
            formBloc: _createRideFormBloc,
            rideBloc: _rideBloc,
            onCreated: () {
              context.read<RideBloc>().add(
                RideLoadRequested(user: context.read<AuthBloc>().state.user!),
              );
              setState(() => _selectedIndex = 0);
            },
          ),
        );
      case 3:
        return const MyRidesTab();
      case 4:
        return const SettingsScreen();
      default:
        return BlocProvider.value(
          value: _savedPlacesBloc,
          child: ClientHomeScreen(
            onBookTap: () => setState(() => _selectedIndex = 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ResponsiveScaffold(
      destinations: _buildDestinations(l10n),
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
  const MyRidesTab({super.key});

  void loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            title: l10n.failedToLoadRides,
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
                  l10n.noActiveRides,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.useBookTabHint, style: const TextStyle(fontSize: 12)),
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
                              ride.status == RideStatus.confirmed ||
                              ride.status == RideStatus.inProgress ||
                              ride.status == RideStatus.handedOff),
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
                                  l10n.departureTimeReachedFlight(
                                    ride.fullFlightInfo,
                                  ),
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
              final isTracking = ride.isTrackable;
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
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ClientMapScreen(rideId: ride.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.location_on, size: 16),
                                  label: Text(l10n.trackDriver),
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
                                  label: Text(l10n.cancel),
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
    final result = await showAdaptiveDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => const CancelRideDialog(role: PersonRole.client),
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
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToCancelRide(e.toString()))),
          );
        }
      }
    }
  }
}

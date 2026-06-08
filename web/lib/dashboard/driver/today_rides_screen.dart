import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../../modules/driver_management/widgets/widgets.dart';
import '../../modules/core/widgets/widgets.dart';
import '../../modules/core/navigation_helper.dart';
import '../../modules/core/services/websocket_service.dart';
import '../../modules/core/services/location_service.dart';
import '../../widgets/common/notification_bell.dart';
import 'widgets/availability_toggle.dart';
import '../../constants/app_colors.dart';

class TodayRidesScreen extends StatefulWidget {
  const TodayRidesScreen({super.key});

  @override
  State<TodayRidesScreen> createState() => _TodayRidesScreenState();
}

class _TodayRidesScreenState extends State<TodayRidesScreen> {
  StreamSubscription? _wsSubscription;
  StreamSubscription? _locationSubscription;
  DateTime? _lastLocationSent;
  bool _trackingStarted = false;
  RideService? _rideService;
  final Map<String, int> _approachingDistances = {};
  final Map<String, int> _etaMinutes = {};
  Timer? _etaTimer;

  @override
  void initState() {
    super.initState();
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event.isDriverApproaching && event.rideId != null) {
        setState(() {
          _approachingDistances[event.rideId!] = event.distanceMeters ?? 0;
        });
      }
      if (event.isRideAssigned && event.rideId != null) {
        final authState = context.read<AuthBloc>().state;
        if (event.driverId == authState.user?.id) {
          _showRideAssignedDialog(event.rideId!);
        }
      }
    });
    _etaTimer = Timer.periodic(const Duration(seconds: 90), (_) => _refreshEta());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEta());
  }

  Future<void> _refreshEta() async {
    if (!mounted || _rideService == null) return;
    final rideState = context.read<RideBloc>().state;
    final activeRides = rideState.rides.where(
      (r) => r.status == RideStatus.assigned || r.status == RideStatus.inProgress,
    );
    for (final ride in activeRides) {
      final data = await _rideService!.getDriverProximity(ride.id);
      if (!mounted) return;
      final eta = data?['etaMinutes'] as int?;
      if (eta != null) {
        setState(() => _etaMinutes[ride.id] = eta);
      }
    }
  }

  Future<void> _showRideAssignedDialog(String rideId) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New ride assigned'),
        content: const Text('You have been assigned a new ride. Do you accept it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (accepted == true) {
      context.read<RideBloc>().add(
        RideLoadRequested(user: context.read<AuthBloc>().state.user!),
      );
    } else {
      try {
        await _rideService?.updateRideStatus(rideId, RideStatus.requested);
        if (mounted) {
          context.read<RideBloc>().add(
            RideLoadRequested(user: context.read<AuthBloc>().state.user!),
          );
        }
      } catch (_) {
        // best-effort
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideService ??= RideService(apiClient: context.read<AuthBloc>().apiClient);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _etaTimer?.cancel();
    _stopLocationTracking();
    _rideService?.dispose();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;

    final started = await LocationService.instance.startLocationTracking();
    _trackingStarted = started;
    if (!started) return;

    _locationSubscription = LocationService.instance.positionStream.listen((position) {
      if (!mounted) return;
      _sendLocationUpdate(position.latitude, position.longitude);
    });
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackingStarted = false;
    LocationService.instance.stopLocationTracking();
  }

  void _sendLocationUpdate(double latitude, double longitude) {
    final now = DateTime.now();
    if (_lastLocationSent != null &&
        now.difference(_lastLocationSent!).inSeconds < 10) {
      return;
    }
    _lastLocationSent = now;

    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated || authState.user == null) return;

    _rideService?.updateDriverLocation(authState.user!.id, latitude, longitude);
  }

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
        backgroundColor: AppColors.infoStrong,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const NotificationBell(),
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
          // Restore tracking if the ride is already in progress (after screen reload)
          if (state.status == RideStateStatus.loaded && !_trackingStarted) {
            final hasActiveRide = state.rides.any((r) => r.status == RideStatus.inProgress);
            if (hasActiveRide) _startLocationTracking();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.infoStrong, Theme.of(context).colorScheme.surface],
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
          const SliverToBoxAdapter(child: AvailabilityToggle()),
          SliverToBoxAdapter(child: TodayStatsCard(todayRides: todayRides)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final ride = todayRides[index];
                return TodayRideCard(
                  ride: ride,
                  isLast: index == todayRides.length - 1,
                  approachingDistanceMeters: _approachingDistances[ride.id],
                  etaMinutes: _etaMinutes[ride.id],
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
              leading: const Icon(Icons.phone, color: AppColors.success),
              title: const Text('Call'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppColors.info),
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
    _startLocationTracking();
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
              _stopLocationTracking();
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

}

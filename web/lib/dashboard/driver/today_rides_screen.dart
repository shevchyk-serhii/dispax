import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/models/payment_method.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../../modules/core/services/api_client.dart';
import '../../modules/core/widgets/avatar_circle.dart';
import '../../modules/driver_management/services/driver_availability_service.dart';
import '../../modules/driver_management/widgets/widgets.dart';
import '../../modules/core/widgets/widgets.dart';
import '../../modules/core/navigation_helper.dart';
import '../../modules/core/navigation_utils.dart';
import '../../modules/core/services/websocket_service.dart';
import '../../modules/core/services/location_service.dart';
import '../../widgets/common/notification_bell.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/ride_management/helpers/flight_status_l10n.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';
import 'ride_assigned_details.dart';
import 'upcoming_rides_screen.dart';

/// Narrows [rides] to those driven by [driverId]. Rides without an assigned
/// driver (or assigned to someone else) are dropped. Used by "My Rides" so a
/// multi-role user (e.g. a dispatcher who also drives) sees only their own
/// driving work, not the whole company queue the shared RideBloc holds.
List<Ride> ridesDrivenBy(List<Ride> rides, String driverId) =>
    rides.where((r) => r.driverId == driverId).toList();

/// Returns a non-null, user-facing message for an error [RideState].
///
/// An error state can reach the UI with a null [RideState.errorMessage] (e.g.
/// after [RideState.copyWith] scoping), so the error widgets must never `!` it.
/// Falls back to the localized "Failed to load rides", then to a plain English
/// literal when no [AppLocalizations] is available.
String rideErrorMessageOrFallback(String? errorMessage, BuildContext context) =>
    errorMessage ??
    (AppLocalizations.of(context)?.failedToLoadRides ?? 'Failed to load rides');

/// Rides whose pickup falls on the calendar day of [now] — the driver's "Today"
/// tab. Completed/cancelled rides are dropped. The window is `[todayStart,
/// todayEnd)` (today 00:00 inclusive .. tomorrow 00:00 exclusive).
///
/// Pure and `now`-parameterised so it can be unit-tested deterministically, and
/// so it shares an exact day boundary with [upcomingRidesFilter] — a ride is
/// either Today or Upcoming, never both. (Previously the Upcoming list used a
/// bare `isAfter(now)` with no upper-to-Today handoff, so a ride later *today*
/// showed in both tabs.)
List<Ride> todayRidesFilter(List<Ride> rides, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  return rides.where((ride) {
    return !ride.pickupDateTime.isBefore(todayStart) &&
        ride.pickupDateTime.isBefore(todayEnd) &&
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.cancelled;
  }).toList()..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
}

/// Rides scheduled from tomorrow onward — the driver's "Upcoming" tab. Only
/// still-active statuses (requested/assigned/confirmed) are kept.
///
/// The lower bound is tomorrow 00:00 (`todayEnd`), NOT `now`: anything later
/// today belongs to [todayRidesFilter], so excluding it here removes the
/// duplicate render across the two tabs.
List<Ride> upcomingRidesFilter(List<Ride> rides, DateTime now) {
  final todayEnd = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));

  return rides.where((ride) {
    return !ride.pickupDateTime.isBefore(todayEnd) &&
        (ride.status == RideStatus.assigned ||
            ride.status == RideStatus.confirmed ||
            ride.status == RideStatus.requested);
  }).toList()..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
}

// ─── Tab index for the segmented control ─────────────────────────────────────
enum _TodayTab { today, upcoming, history }

class TodayRidesScreen extends StatefulWidget {
  const TodayRidesScreen({super.key});

  @override
  State<TodayRidesScreen> createState() => _TodayRidesScreenState();
}

class _TodayRidesScreenState extends State<TodayRidesScreen>
    with SingleTickerProviderStateMixin {
  // ── Preserved verbatim: WS / ETA / location state ─────────────────────────
  StreamSubscription? _wsSubscription;
  StreamSubscription? _locationSubscription;
  DateTime? _lastLocationSent;
  bool _trackingStarted = false;
  RideService? _rideService;
  final Map<String, int> _approachingDistances = {};
  final Map<String, int> _etaMinutes = {};
  Timer? _etaTimer;

  // ── New: tab + pulse animation ─────────────────────────────────────────────
  _TodayTab _activeTab = _TodayTab.today;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing green dot animation (1.2s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Preserved verbatim: WS event listener ──────────────────────────────
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

    // ── Preserved verbatim: 90-second ETA timer ────────────────────────────
    _etaTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshEta(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEta());
  }

  // ── Preserved verbatim ────────────────────────────────────────────────────
  Future<void> _refreshEta() async {
    if (!mounted || _rideService == null) return;
    final myId = context.read<AuthBloc>().state.user?.id;
    final rideState = context.read<RideBloc>().state;
    final activeRides = rideState.rides.where(
      (r) =>
          r.driverId == myId &&
          (r.status == RideStatus.assigned ||
              r.status == RideStatus.confirmed ||
              r.status == RideStatus.inProgress),
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
    // Fetch the full ride so the driver sees pickup, destination, client, and
    // price before deciding. A failed fetch falls back to the generic text.
    Ride? ride;
    try {
      ride = await _rideService?.getRideById(rideId);
    } catch (_) {
      ride = null;
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final accepted = await showAdaptiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newRideAssigned),
        content: RideAssignedDetails(ride: ride),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.decline),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.accept),
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
    _pulseController.dispose();
    _stopLocationTracking();
    _rideService?.dispose();
    super.dispose();
  }

  // ── Preserved verbatim: location tracking ──────────────────────────────────
  Future<void> _startLocationTracking() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;

    final started = await LocationService.instance.startLocationTracking();
    _trackingStarted = started;
    if (!started) return;

    _locationSubscription = LocationService.instance.positionStream.listen((
      position,
    ) {
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: BlocListener<RideBloc, RideState>(
              listener: (context, state) {
                if (state.hasError) {
                  NavigationHelper.showSnackBar(
                    context,
                    rideErrorMessageOrFallback(state.errorMessage, context),
                    isError: true,
                  );
                }
                // Restore tracking if the ride is already in progress (after screen reload)
                if (state.status == RideStateStatus.loaded &&
                    !_trackingStarted) {
                  final myId = context.read<AuthBloc>().state.user?.id;
                  final hasActiveRide = state.rides.any(
                    (r) =>
                        r.driverId == myId &&
                        (r.status == RideStatus.inProgress ||
                            r.status == RideStatus.confirmed),
                  );
                  if (hasActiveRide) _startLocationTracking();
                }
              },
              child: BlocBuilder<RideBloc, RideState>(
                builder: (context, rideState) {
                  final content = _buildTabContent(context, rideState);
                  // HANDOFF §11: on web/desktop (>= 800) constrain the content
                  // width so ride cards don't stretch across a wide viewport.
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >=
                          AppDimensions.breakpointDesktop) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppDimensions.maxContentWidth,
                            ),
                            child: content,
                          ),
                        );
                      }
                      return content;
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Graphite header ──────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: eyebrow title + bell + refresh
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eyebrow: "SAT · 20 JUNE"
                        Text(
                          _formatEyebrow(DateTime.now()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.66,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Title "Today"
                        Text(
                          l10n.today,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => refreshRides(context),
                    tooltip: l10n.refresh,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Availability pill
              _AvailabilityPill(pulseAnimation: _pulseAnimation),

              const SizedBox(height: 12),

              // Segmented control (Today N | Upcoming | History)
              BlocBuilder<RideBloc, RideState>(
                builder: (context, rideState) {
                  final myRideState = _scopeToMyRides(context, rideState);
                  final todayCount = getTodayRides(myRideState.rides).length;
                  return _SegmentedControl(
                    activeTab: _activeTab,
                    todayCount: todayCount,
                    onTabChanged: (tab) => setState(() => _activeTab = tab),
                  );
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEyebrow(DateTime date) {
    final dayName = DateFormat('EEE').format(date).toUpperCase();
    final day = date.day;
    final month = DateFormat('MMMM').format(date).toUpperCase();
    return '$dayName · $day $month';
  }

  // ─── Tab content switcher ─────────────────────────────────────────────────

  Widget _buildTabContent(BuildContext context, RideState rideState) {
    // The shared RideBloc holds every ride the current user can see. For a
    // dispatcher (or any multi-role user) that is the whole company queue, so
    // this "My Rides" screen must narrow it down to the rides the current user
    // drives themselves — otherwise it would mirror the dispatcher Home tab.
    final myRideState = _scopeToMyRides(context, rideState);
    switch (_activeTab) {
      case _TodayTab.upcoming:
        return _EmbeddedUpcomingTab(
          rideState: myRideState,
          onRefresh: () => refreshRides(context),
        );
      case _TodayTab.history:
        return _EmbeddedHistoryTab(rideState: myRideState);
      case _TodayTab.today:
        return buildBody(context, myRideState);
    }
  }

  /// Returns [rideState] with its ride list narrowed to the rides assigned to
  /// the current user. Rides without an assigned driver are excluded, since
  /// "My Rides" only ever shows the user's own driving work.
  RideState _scopeToMyRides(BuildContext context, RideState rideState) {
    final myId = context.read<AuthBloc>().state.user?.id;
    if (myId == null) return rideState;
    return rideState.copyWith(rides: ridesDrivenBy(rideState.rides, myId));
  }

  // ─── Today body ───────────────────────────────────────────────────────────

  Widget buildBody(BuildContext context, RideState rideState) {
    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadTodayRides(context),
      );
    }

    if (rideState.isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        title: "Failed to load today's rides",
        message: rideErrorMessageOrFallback(rideState.errorMessage, context),
        onRetry: () => refreshRides(context),
      );
    }

    final todayRides = getTodayRides(rideState.rides);

    if (todayRides.isEmpty) {
      return buildEmptyState();
    }

    // Every ride of the day gets the same detailed card. The card is fully
    // status-aware (badge, ETA gating, action buttons), so an in-progress ride
    // and a later assigned ride render with the same level of detail — fare,
    // payment method, flight info and all. [getTodayRides] already sorts by
    // pickup time, so the list order is chronological.
    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final ride = todayRides[index];
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                  child: DriverRideCard(
                    ride: ride,
                    etaMinutes: _etaMinutes[ride.id],
                    approachingDistanceMeters: _approachingDistances[ride.id],
                    onStartRide: () => _handleStartRide(context, ride),
                    onCompleteRide: () => _handleCompleteRide(context, ride),
                    onCallClient: () => _handleCallClient(context, ride),
                    onConfirmRide: () => _handleConfirmRide(context, ride),
                    onRejectRide: () => _handleRejectRide(context, ride),
                  ),
                );
              }, childCount: todayRides.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() => const EmptyRidesState();

  // ── Preserved verbatim: action handlers ───────────────────────────────────

  void _handleCallClient(BuildContext context, Ride ride) {
    final phone = ride.client.phone;
    if (phone == null || phone.isEmpty) {
      NavigationHelper.showSnackBar(
        context,
        'No phone number available',
        isError: true,
      );
      return;
    }
    _showContactOptions(context, phone);
  }

  void _showContactOptions(BuildContext context, String phone) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.success),
              title: Text(l10n.call),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppColors.info),
              title: Text(l10n.sms),
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
    context.read<RideBloc>().add(
      RideStatusUpdateRequested(rideId: ride.id, status: RideStatus.inProgress),
    );
    _startLocationTracking();
    NavigationHelper.showSnackBar(context, 'Ride started');
  }

  void _handleCompleteRide(BuildContext context, Ride ride) {
    final l10n = AppLocalizations.of(context)!;
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.completeRideTitle),
        content: Text(
          'Mark ride from ${ride.from.address} to ${ride.to.address} as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RideBloc>().add(
                RideStatusUpdateRequested(
                  rideId: ride.id,
                  status: RideStatus.completed,
                ),
              );
              _stopLocationTracking();
              NavigationHelper.showSnackBar(context, 'Ride completed');
            },
            child: Text(l10n.completeRideButton),
          ),
        ],
      ),
    );
  }

  void _handleConfirmRide(BuildContext context, Ride ride) {
    context.read<RideBloc>().add(RideConfirmRequested(rideId: ride.id));
    NavigationHelper.showSnackBar(context, 'Ride confirmed');
  }

  void _handleRejectRide(BuildContext context, Ride ride) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<RideBloc>();
    showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => RejectRideDialog(ride: ride),
    ).then((reason) {
      if (reason == null || reason.isEmpty || !context.mounted) return;
      bloc.add(RideRejectRequested(rideId: ride.id, reason: reason));
      NavigationHelper.showSnackBar(context, l10n.rideRejected);
    });
  }

  List<Ride> getTodayRides(List<Ride> rides) =>
      todayRidesFilter(rides, DateTime.now());
}

// ─────────────────────────────────────────────────────────────────────────────
// Availability Pill (inside the graphite header; mirrors AvailabilityToggle
// logic without Card shell, styled per spec)
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityPill extends StatefulWidget {
  final Animation<double> pulseAnimation;

  const _AvailabilityPill({required this.pulseAnimation});

  @override
  State<_AvailabilityPill> createState() => _AvailabilityPillState();
}

class _AvailabilityPillState extends State<_AvailabilityPill> {
  bool _isAvailable = false;
  bool _isUpdating = false;

  // Once the driver has changed availability themselves, the in-flight initial
  // load (or any later reload) must not overwrite that choice with the stale
  // server value it captured before the toggle. This guard makes the user's
  // action win the race and prevents the Switch from snapping back.
  bool _userHasToggled = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    final service = DriverAvailabilityService(
      context.read<AuthBloc>().apiClient,
    );
    final available = await service.isAvailable(user.id.toString());
    // Drop a load that resolved after the user already toggled — its value is
    // stale and would snap the Switch back to the pre-toggle state.
    if (mounted && !_userHasToggled) {
      setState(() => _isAvailable = available);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.selectionClick();
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    setState(() {
      _isUpdating = true;
      _userHasToggled = true;
    });
    try {
      final service = DriverAvailabilityService(
        context.read<AuthBloc>().apiClient,
      );
      final ok = await service.setAvailable(user.id.toString(), value);
      if (ok && mounted) {
        setState(() => _isAvailable = value);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToUpdate(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const greenDot = Color(0xFF22C55E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Pulsing green dot (online) / static grey dot (offline)
          AnimatedBuilder(
            animation: widget.pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAvailable
                      ? greenDot.withValues(alpha: widget.pulseAnimation.value)
                      : AppColors.textSecondary,
                  boxShadow: _isAvailable
                      ? [
                          BoxShadow(
                            color: greenDot.withValues(
                              alpha: widget.pulseAnimation.value * 0.6,
                            ),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isAvailable ? l10n.youreOnline : l10n.youreOffline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isUpdating)
            const SizedBox(
              width: 44,
              height: 26,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 44,
              height: 26,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch.adaptive(
                  value: _isAvailable,
                  onChanged: _toggleAvailability,
                  activeTrackColor: AppColors.accent,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented control
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final _TodayTab activeTab;
  final int todayCount;
  final ValueChanged<_TodayTab> onTabChanged;

  const _SegmentedControl({
    required this.activeTab,
    required this.todayCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _SegmentTab(
            label: '${l10n.today} · $todayCount',
            active: activeTab == _TodayTab.today,
            onTap: () => onTabChanged(_TodayTab.today),
          ),
          _SegmentTab(
            label: l10n.upcoming,
            active: activeTab == _TodayTab.upcoming,
            onTap: () => onTabChanged(_TodayTab.upcoming),
          ),
          _SegmentTab(
            label: l10n.history,
            active: activeTab == _TodayTab.history,
            onTap: () => onTabChanged(_TodayTab.history),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          height: double.infinity,
          decoration: active
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                )
              : null,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? AppColors.textPrimary
                    : Colors.white.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE RIDE CARD  (in-progress or assigned)
// ─────────────────────────────────────────────────────────────────────────────

/// The driver's detailed ride card, used for **every** ride of the day on the
/// "Heute" tab. Renders client avatar + fare, payment method, full flight info,
/// arrival/entry times, the route connector, ETA/approaching chips, and the
/// status-aware action buttons. It is fully parameterised by [ride.status], so
/// the same card serves an in-progress ride and a later assigned one alike.
///
/// Public (not `_LiveRideCard`) so a widget test can locate it directly.
class DriverRideCard extends StatelessWidget {
  final Ride ride;
  final int? etaMinutes;
  final int? approachingDistanceMeters;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onCallClient;
  final VoidCallback? onConfirmRide;
  final VoidCallback? onRejectRide;

  const DriverRideCard({
    super.key,
    required this.ride,
    this.etaMinutes,
    this.approachingDistanceMeters,
    this.onStartRide,
    this.onCompleteRide,
    this.onCallClient,
    this.onConfirmRide,
    this.onRejectRide,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final statusBg = RideStatusStyles.getStatusBackgroundColor(
      ride.status,
      brightness: brightness,
    );
    final statusBorder = RideStatusStyles.getStatusBorderColor(
      ride.status,
      brightness: brightness,
    );
    final statusTextColor = RideStatusStyles.getStatusTextColor(
      ride.status,
      brightness: brightness,
    );
    final statusDotColor = RideStatusStyles.getStatusColor(ride.status);
    final statusLabel = RideStatusStyles.getStatusDisplayName(
      ride.status,
      AppLocalizations.of(context)!,
    );

    return Container(
      decoration: AppStyles.primaryCardDecorationOf(context).copyWith(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMd,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Tapping the card (outside the action buttons) opens the full ride
      // details — the only place that exposes the "Share" tracking link.
      child: InkWell(
        onTap: () => NavigationUtils.navigateToRideDetails(context, ride),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge + pickup time
              Row(
                children: [
                  _StatusBadge(
                    bg: statusBg,
                    border: statusBorder,
                    dot: statusDotColor,
                    textColor: statusTextColor,
                    label: statusLabel,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pickup ${DateFormat.Hm().format(ride.pickupDateTime)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Client avatar + name + fare. The driver needs to know who the
              // ride is for and how much it is at a glance.
              DriverClientPriceRow(
                ride: ride,
                isDark: isDark,
                apiClient: context.read<AuthBloc>().apiClient,
              ),

              // Payment method (how the driver will be paid).
              DriverPaymentRow(ride: ride, isDark: isDark),

              // Full flight info for airport rides (number + gate/terminal + status).
              DriverFlightInfoRow(ride: ride, isDark: isDark),
              DriverArrivalTimeRow(ride: ride, isDark: isDark),
              DriverEntryTimeRow(ride: ride, isDark: isDark),

              const SizedBox(height: 14),

              // Route connector (accent dot → line → primary square)
              _RouteConnector(ride: ride, isDark: isDark),

              const SizedBox(height: 14),

              // ETA chip + approaching chip (flight moved to its own full-info row above).
              // ETA is only shown after the driver starts the ride (inProgress)
              if ((etaMinutes != null &&
                      ride.status == RideStatus.inProgress) ||
                  approachingDistanceMeters != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (etaMinutes != null &&
                        ride.status == RideStatus.inProgress)
                      _EtaChip(etaMinutes: etaMinutes!),
                    if (approachingDistanceMeters != null)
                      _ApproachingChip(
                        distanceMeters: approachingDistanceMeters!,
                      ),
                  ],
                ),

              if ((etaMinutes != null &&
                      ride.status == RideStatus.inProgress) ||
                  approachingDistanceMeters != null)
                const SizedBox(height: 14),

              // Action buttons
              DriverRideActionsRow(
                ride: ride,
                isDark: isDark,
                onNavigate: () =>
                    NavigationUtils.showNavigateToDialog(context, ride),
                onShareRide: () => NavigationUtils.shareRide(context, ride),
                onCallClient: onCallClient,
                onConfirmRide: onConfirmRide,
                onRejectRide: onRejectRide,
                onStartRide: onStartRide,
                onCompleteRide: onCompleteRide,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client name + fare row (driver needs both at a glance)
// ─────────────────────────────────────────────────────────────────────────────

class DriverClientPriceRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;
  final ApiClient apiClient;

  const DriverClientPriceRow({
    super.key,
    required this.ride,
    required this.isDark,
    required this.apiClient,
  });

  /// Formats the fare amount, dropping a trailing ".0" so a whole-euro fare
  /// reads "45", not "45.0". The euro symbol is rendered by the adjacent
  /// [Icons.euro], so it must NOT be prefixed here (that produced "€ €100").
  String _formatPrice(double price) {
    return price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Provisional rides: show the route label + "Add client details" action
    // instead of the placeholder name that the backend assigned.
    if (ride.clientProvisional) {
      return Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 15, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.fromChatRide,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: secondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showLinkClientDialog(context, l10n),
            child: Text(
              l10n.linkClient,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          if (ride.price != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.euro, size: 15, color: secondary),
            const SizedBox(width: 2),
            Text(
              _formatPrice(ride.price!),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ],
      );
    }

    final name = ride.clientName.trim();
    // 'Unknown Client' is the model's fallback when the server sent no name;
    // showing it adds noise, so treat it as absent.
    final hasName = name.isNotEmpty && name != 'Unknown Client';
    final hasPrice = ride.price != null;
    if (!hasName && !hasPrice) return const SizedBox.shrink();

    return Row(
      children: [
        if (hasName) ...[
          // Client photo (falls back to initials when none is set).
          AvatarCircle(user: ride.client, apiClient: apiClient, radius: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ] else
          const Spacer(),
        if (hasPrice) ...[
          const SizedBox(width: 8),
          Icon(Icons.euro, size: 15, color: secondary),
          const SizedBox(width: 2),
          Text(
            _formatPrice(ride.price!),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      ],
    );
  }

  void _showLinkClientDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _LinkClientDialog(ride: ride),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Link-client dialog: upgrade a provisional client with real contact details
// ─────────────────────────────────────────────────────────────────────────────

class _LinkClientDialog extends StatefulWidget {
  final Ride ride;

  const _LinkClientDialog({required this.ride});

  @override
  State<_LinkClientDialog> createState() => _LinkClientDialogState();
}

class _LinkClientDialogState extends State<_LinkClientDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameCtrl.text.trim().isEmpty && _phoneCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.enterClientNameError);
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final authBloc = context.read<AuthBloc>();
      final service = RideService(apiClient: authBloc.apiClient);
      await service.upgradeProvisionalClient(
        widget.ride.clientId,
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        phone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
      );
      service.dispose();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.linkClient),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Client name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.closeButton),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.linkClient),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method row (how the driver gets paid for this ride)
// ─────────────────────────────────────────────────────────────────────────────

class DriverPaymentRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;

  const DriverPaymentRow({super.key, required this.ride, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final label = PaymentMethod.labelForWire(
      ride.paymentMethod,
      AppLocalizations.of(context)!,
    );
    if (label == null) return const SizedBox.shrink();

    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 16, color: secondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: secondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full flight info row for airport rides (number + gate/terminal + status)
// ─────────────────────────────────────────────────────────────────────────────

class DriverFlightInfoRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;

  const DriverFlightInfoRow({
    super.key,
    required this.ride,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (!ride.isAirportTransfer || ride.fullFlightInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final statusText = AppLocalizations.of(
      context,
    )!.localizedFlightStatus(ride.flightStatus);
    final flightLine = statusText.isEmpty
        ? ride.fullFlightInfo
        : '${ride.fullFlightInfo} • ${ride.flightStatusIcon} $statusText';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ride.flightIconData != null) ...[
            Icon(ride.flightIconData, size: 15, color: secondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              flightLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recommended terminal-entry time ("Einfahrt um HH:mm") for an airport ARRIVAL ride.
/// Backend-computed (terminal-aware walk buffer), GPS-free, carried on the ride DTO — so it
/// shows on the static "Today" / "My Rides" cards. Renders nothing for departures or when no
/// entry time was computed. Shared by the live, next and compact ride cards.
class DriverEntryTimeRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;

  const DriverEntryTimeRow({
    super.key,
    required this.ride,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (!ride.isArrivalAirportTransfer || ride.optimalEntryTime == null) {
      return const SizedBox.shrink();
    }

    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.login, size: 15, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.airportEntryAt(DateFormat.Hm().format(ride.optimalEntryTime!)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flight arrival/landing time ("Landung um HH:mm") for an airport ride, with a red delay
/// suffix ("+N Min Verspätung") when the flight is late. The live flight time comes from the
/// airport board (FlightStatusMonitor) on the ride DTO. Renders nothing without a flight time.
/// Shared by the live, next and compact ride cards.
class DriverArrivalTimeRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;

  const DriverArrivalTimeRow({
    super.key,
    required this.ride,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (!ride.isAirportTransfer || ride.flightTime == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final delay = ride.flightDelayMinutes;
    final showDelay = ride.isFlightDelayed;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flight_land, size: 15, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.airportArrivalText(ride)),
                  if (showDelay)
                    TextSpan(
                      text: delay != null && delay > 0
                          ? '  •  ${l10n.airportFlightDelay(delay)}'
                          : '  •  ${l10n.flightStatusDelayed}',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route connector (accent dot → vertical line → graphite square)
// ─────────────────────────────────────────────────────────────────────────────

class _RouteConnector extends StatelessWidget {
  final Ride ride;
  final bool isDark;

  const _RouteConnector({required this.ride, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connector column
        Column(
          children: [
            // Accent ring dot (origin)
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.accentLight, width: 2.5),
              ),
            ),
            // Vertical line
            Container(
              width: 2,
              height: 28,
              color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
            ),
            // Graphite destination square
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Address column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.from.address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                ride.to.address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (dot + label in tinted pill)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final Color bg;
  final Color border;
  final Color dot;
  final Color textColor;
  final String label;

  const _StatusBadge({
    required this.bg,
    required this.border,
    required this.dot,
    required this.textColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ETA chip
// ─────────────────────────────────────────────────────────────────────────────

class _EtaChip extends StatelessWidget {
  final int etaMinutes;

  const _EtaChip({required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Accent-tinted chip that stays legible on both light and dark cards.
    final fill = isDark
        ? AppColors.accent.withValues(alpha: 0.16)
        : const Color(0xFFF0F9FF);
    final border = isDark
        ? AppColors.accent.withValues(alpha: 0.40)
        : const Color(0xFFBAE6FD);
    final fg = isDark ? AppColors.accentLight : const Color(0xFF075985);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context)!.arrivingInMinutes(etaMinutes),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approaching chip
// ─────────────────────────────────────────────────────────────────────────────

class _ApproachingChip extends StatelessWidget {
  final int distanceMeters;

  const _ApproachingChip({required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final color = distanceMeters <= 100
        ? AppColors.success
        : distanceMeters <= 500
        ? AppColors.accent
        : AppColors.info;
    final label = distanceMeters <= 100
        ? 'Arrived'
        : distanceMeters < 1000
        ? '${distanceMeters}m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded Upcoming tab (reuses UpcomingRidesScreen.buildBody directly)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedUpcomingTab extends StatelessWidget {
  final RideState rideState;
  final VoidCallback onRefresh;

  const _EmbeddedUpcomingTab({
    required this.rideState,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // [rideState] is already scoped to the current user's own rides by the
    // parent, so the embedded Upcoming view never leaks other drivers' rides.
    final screen = UpcomingRidesScreen();
    return screen.buildBody(context, rideState);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded History tab (shows completed / cancelled rides)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedHistoryTab extends StatelessWidget {
  final RideState rideState;

  const _EmbeddedHistoryTab({required this.rideState});

  @override
  Widget build(BuildContext context) {
    // [rideState] is already scoped to the current user's own rides by the
    // parent, so History only shows the user's own completed/cancelled rides.
    if (rideState.isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }
    final finished =
        rideState.rides
            .where(
              (r) =>
                  r.status == RideStatus.completed ||
                  r.status == RideStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));

    if (finished.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noCompletedRides,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: finished.length,
      itemBuilder: (context, index) {
        final ride = finished[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TodayRideCard(
            ride: ride,
            isLast: index == finished.length - 1,
          ),
        );
      },
    );
  }
}

/// Action button row shown at the bottom of a [DriverRideCard].
///
/// Navigate plus the status-specific primary actions (Confirm/Reject, Start,
/// Complete) each take an equal share of the available width via [Expanded] so
/// the row always fits the card — even on narrow screens — instead of letting
/// the trailing button overflow off the right edge. The phone button keeps a
/// fixed 40x40 footprint.
class DriverRideActionsRow extends StatelessWidget {
  final Ride ride;
  final bool isDark;
  final VoidCallback onNavigate;
  final VoidCallback? onShareRide;
  final VoidCallback? onCallClient;
  final VoidCallback? onConfirmRide;
  final VoidCallback? onRejectRide;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;

  const DriverRideActionsRow({
    super.key,
    required this.ride,
    required this.isDark,
    required this.onNavigate,
    this.onShareRide,
    this.onCallClient,
    this.onConfirmRide,
    this.onRejectRide,
    this.onStartRide,
    this.onCompleteRide,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iconColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Row 1: Navigate (flexible) + icon-only Call / Share, plus the single
    // text action for confirmed/inProgress rides. The two-action `assigned`
    // case gets its own full-width second row below so the German labels
    // ("Bestätigen", "Ablehnen") never have to share width with Navigate and
    // therefore never truncate.
    final firstRow = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: Tooltip(
              message: l10n.navigate,
              child: FilledButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text(
                  l10n.navigate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: l10n.callClient,
          child: SizedBox(
            width: 40,
            height: 40,
            child: OutlinedButton(
              onPressed: onCallClient,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppColors.borderSecondary,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Icon(Icons.phone_outlined, size: 18, color: iconColor),
            ),
          ),
        ),
        if (onShareRide != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.shareRideLink,
            child: SizedBox(
              width: 40,
              height: 40,
              child: OutlinedButton(
                onPressed: onShareRide,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.borderSecondary,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ],
        if (ride.status == RideStatus.confirmed && onStartRide != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: Tooltip(
                message: l10n.start,
                child: FilledButton.icon(
                  onPressed: onStartRide,
                  icon: const Icon(Icons.play_circle_rounded, size: 16),
                  label: Text(
                    l10n.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (ride.status == RideStatus.inProgress && onCompleteRide != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: Tooltip(
                message: l10n.completeRideButton,
                child: FilledButton.icon(
                  onPressed: onCompleteRide,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    l10n.completeRideButton,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    if (ride.status != RideStatus.assigned) {
      return firstRow;
    }

    // Row 2 (assigned only): Confirm + Reject across the full card width.
    final confirmReject = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: Tooltip(
              message: l10n.confirm,
              // No leading icon here: at phone width two full-width buttons
              // already leave little room, and an icon would push the German
              // "Bestätigen" back into ellipsis territory.
              child: FilledButton(
                onPressed: onConfirmRide,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                  ),
                ),
                child: Text(
                  l10n.confirm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: Tooltip(
              message: l10n.rejectButton,
              child: OutlinedButton(
                onPressed: onRejectRide,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.errorBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                  ),
                ),
                child: Text(
                  l10n.rejectButton,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [firstRow, const SizedBox(height: 8), confirmReject],
    );
  }
}

/// A preset rejection reason: a localized chip [label] plus the stable English
/// [backendReason] that is actually sent to the API (so the wire value does not
/// change with the driver's UI language). [backendReason] is null for the
/// "Other" chip, which reveals a free-text field instead.
class _RejectReasonPreset {
  final String label;
  final String? backendReason;

  const _RejectReasonPreset(this.label, this.backendReason);
}

/// Reject Ride dialog: lets the driver pick a typical rejection reason in one
/// tap (preset chips) or enter a custom reason via the "Other" chip. Returns
/// the chosen reason string through [Navigator.pop]; returns null on cancel.
class RejectRideDialog extends StatefulWidget {
  final Ride ride;

  const RejectRideDialog({super.key, required this.ride});

  @override
  State<RejectRideDialog> createState() => _RejectRideDialogState();
}

class _RejectRideDialogState extends State<RejectRideDialog> {
  final TextEditingController _customController = TextEditingController();

  /// Index of the selected preset chip, or null when nothing is selected yet.
  int? _selectedIndex;

  /// True when the selected chip is the "Other" chip (last in the list), which
  /// reveals the free-text field.
  bool _isOther = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  List<_RejectReasonPreset> _presets(AppLocalizations l10n) => [
    _RejectReasonPreset(l10n.rejectReasonTooFar, 'Pickup too far'),
    _RejectReasonPreset(l10n.rejectReasonBusy, 'Busy with another ride'),
    _RejectReasonPreset(l10n.rejectReasonBreak, 'On break / end of shift'),
    _RejectReasonPreset(l10n.rejectReasonVehicleIssue, 'Vehicle issue'),
    _RejectReasonPreset(l10n.rejectReasonOther, null),
  ];

  String? _resolveReason(List<_RejectReasonPreset> presets) {
    final index = _selectedIndex;
    if (index == null) return null;
    final preset = presets[index];
    if (preset.backendReason != null) return preset.backendReason;
    final custom = _customController.text.trim();
    return custom.isEmpty ? null : custom;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final presets = _presets(l10n);
    final reason = _resolveReason(presets);

    return AlertDialog(
      title: Text(l10n.rejectRide),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reject ride from ${widget.ride.from.address} '
            'to ${widget.ride.to.address}?',
          ),
          const SizedBox(height: 16),
          Text(
            l10n.rejectReasonPrompt,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < presets.length; i++)
                ChoiceChip(
                  label: Text(presets[i].label),
                  selected: _selectedIndex == i,
                  selectedColor: colorScheme.primaryContainer,
                  onSelected: (_) {
                    setState(() {
                      _selectedIndex = i;
                      _isOther = presets[i].backendReason == null;
                    });
                  },
                ),
            ],
          ),
          if (_isOther) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.rejectReasonPrompt,
              ),
              maxLines: 2,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: reason == null
              ? null
              : () => Navigator.pop(context, reason),
          child: Text(l10n.rejectButton),
        ),
      ],
    );
  }
}

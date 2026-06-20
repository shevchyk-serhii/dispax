import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';
import 'upcoming_rides_screen.dart';

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
    final rideState = context.read<RideBloc>().state;
    final activeRides = rideState.rides.where(
      (r) =>
          r.status == RideStatus.assigned || r.status == RideStatus.inProgress,
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

  // ── Preserved verbatim ────────────────────────────────────────────────────
  Future<void> _showRideAssignedDialog(String rideId) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New ride assigned'),
        content: const Text(
          'You have been assigned a new ride. Do you accept it?',
        ),
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
                    state.errorMessage!,
                    isError: true,
                  );
                }
                // Restore tracking if the ride is already in progress (after screen reload)
                if (state.status == RideStateStatus.loaded &&
                    !_trackingStarted) {
                  final hasActiveRide = state.rides.any(
                    (r) => r.status == RideStatus.inProgress,
                  );
                  if (hasActiveRide) _startLocationTracking();
                }
              },
              child: BlocBuilder<RideBloc, RideState>(
                builder: (context, rideState) {
                  return _buildTabContent(context, rideState);
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
                        const Text(
                          'Today',
                          style: TextStyle(
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
                    tooltip: 'Refresh',
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
                  final todayCount = getTodayRides(rideState.rides).length;
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
    switch (_activeTab) {
      case _TodayTab.upcoming:
        return _EmbeddedUpcomingTab(onRefresh: () => refreshRides(context));
      case _TodayTab.history:
        return _EmbeddedHistoryTab();
      case _TodayTab.today:
        return buildBody(context, rideState);
    }
  }

  // ─── Today body ───────────────────────────────────────────────────────────

  Widget buildBody(BuildContext context, RideState rideState) {
    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadTodayRides(context),
      );
    }

    if (rideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        title: "Failed to load today's rides",
        message: rideState.errorMessage!,
        onRetry: () => refreshRides(context),
      );
    }

    final todayRides = getTodayRides(rideState.rides);

    if (todayRides.isEmpty) {
      return buildEmptyState();
    }

    // The "live" ride: in-progress first, then first assigned
    final liveRide = todayRides.firstWhere(
      (r) => r.status == RideStatus.inProgress,
      orElse: () => todayRides.firstWhere(
        (r) => r.status == RideStatus.assigned,
        orElse: () => todayRides.first,
      ),
    );
    final isLiveActive =
        liveRide.status == RideStatus.inProgress ||
        liveRide.status == RideStatus.assigned;

    // Remaining rides (excluding live)
    final remainingRides = isLiveActive
        ? todayRides.where((r) => r.id != liveRide.id).toList()
        : todayRides;

    // "Next" scheduled ride after the live one
    Ride? nextRide;
    if (isLiveActive && remainingRides.isNotEmpty) {
      final candidate = remainingRides.firstWhere(
        (r) => r.status == RideStatus.assigned,
        orElse: () => remainingRides.first,
      );
      if (candidate.status == RideStatus.assigned) {
        nextRide = candidate;
      }
    }

    final otherRides = remainingRides
        .where((r) => r.id != nextRide?.id)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: CustomScrollView(
        slivers: [
          // LIVE RIDE CARD
          if (isLiveActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _LiveRideCard(
                  ride: liveRide,
                  etaMinutes: _etaMinutes[liveRide.id],
                  approachingDistanceMeters: _approachingDistances[liveRide.id],
                  onStartRide: () => _handleStartRide(context, liveRide),
                  onCompleteRide: () => _handleCompleteRide(context, liveRide),
                  onCallClient: () => _handleCallClient(context, liveRide),
                ),
              ),
            ),

          // NEXT SCHEDULED RIDE CARD
          if (nextRide != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _NextRideCard(ride: nextRide),
              ),
            ),

          // Remaining ride cards
          if (otherRides.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ride = otherRides[index];
                  return TodayRideCard(
                    ride: ride,
                    isLast: index == otherRides.length - 1,
                    approachingDistanceMeters: _approachingDistances[ride.id],
                    etaMinutes: _etaMinutes[ride.id],
                    onCallClient: () => _handleCallClient(context, ride),
                    onStartRide: () => _handleStartRide(context, ride),
                    onCompleteRide: () => _handleCompleteRide(context, ride),
                  );
                }, childCount: otherRides.length),
              ),
            ),

          if (otherRides.isEmpty && !isLiveActive)
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    context.read<RideBloc>().add(
      RideStatusUpdateRequested(rideId: ride.id, status: RideStatus.inProgress),
    );
    _startLocationTracking();
    NavigationHelper.showSnackBar(context, 'Ride started');
  }

  void _handleCompleteRide(BuildContext context, Ride ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Ride'),
        content: Text(
          'Mark ride from ${ride.from.address} to ${ride.to.address} as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final user = context.read<AuthBloc>().state.user;
      if (user == null) return;
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/drivers/${user.id}/availability');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _isAvailable = data['status'] == 'Available';
        });
      }
    } catch (_) {
      // Silently handle - default to offline
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.selectionClick();
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    setState(() => _isUpdating = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.put('/drivers/${user.id}/availability', {
        'status': value ? 'Available' : 'Offline',
      });
      if (response.statusCode == 200 && mounted) {
        setState(() => _isAvailable = value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
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
              _isAvailable ? "You're online" : "You're offline",
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
            label: 'Today · $todayCount',
            active: activeTab == _TodayTab.today,
            onTap: () => onTabChanged(_TodayTab.today),
          ),
          _SegmentTab(
            label: 'Upcoming',
            active: activeTab == _TodayTab.upcoming,
            onTap: () => onTabChanged(_TodayTab.upcoming),
          ),
          _SegmentTab(
            label: 'History',
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

class _LiveRideCard extends StatelessWidget {
  final Ride ride;
  final int? etaMinutes;
  final int? approachingDistanceMeters;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onCallClient;

  const _LiveRideCard({
    required this.ride,
    this.etaMinutes,
    this.approachingDistanceMeters,
    this.onStartRide,
    this.onCompleteRide,
    this.onCallClient,
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
    final statusLabel = RideStatusStyles.getStatusDisplayName(ride.status);

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

            const SizedBox(height: 14),

            // Route connector (accent dot → line → primary square)
            _RouteConnector(ride: ride, isDark: isDark),

            const SizedBox(height: 14),

            // ETA chip + flight badge + approaching chip
            if (etaMinutes != null ||
                ride.flightNumber != null ||
                approachingDistanceMeters != null)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (etaMinutes != null) _EtaChip(etaMinutes: etaMinutes!),
                  if (ride.flightNumber != null)
                    _FlightBadge(flightNumber: ride.flightNumber!),
                  if (approachingDistanceMeters != null)
                    _ApproachingChip(
                      distanceMeters: approachingDistanceMeters!,
                    ),
                ],
              ),

            if (etaMinutes != null ||
                ride.flightNumber != null ||
                approachingDistanceMeters != null)
              const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => _handleNavigate(context, ride),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text(
                        'Navigate',
                        style: TextStyle(
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
                const SizedBox(width: 8),
                SizedBox(
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
                    child: Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (ride.status == RideStatus.assigned &&
                    onStartRide != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: onStartRide,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusButton,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (ride.status == RideStatus.inProgress &&
                    onCompleteRide != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: onCompleteRide,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Complete',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusButton,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _handleNavigate(BuildContext context, Ride ride) async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (BuildContext ctx) => SimpleDialog(
          title: const Text('Navigate to'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('pickup'),
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppColors.success,
                ),
                title: Text(ride.from.address),
                subtitle: const Text('Google Maps — Pickup'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('destination'),
              child: ListTile(
                leading: const Icon(Icons.flag, color: AppColors.error),
                title: Text(ride.to.address),
                subtitle: const Text('Google Maps — Drop-off'),
              ),
            ),
          ],
        ),
      );

      if (choice == null || !context.mounted) return;

      final loc = choice == 'pickup' ? ride.from : ride.to;
      final Uri mapsUrl;
      if (loc.latitude != null && loc.longitude != null) {
        mapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=${loc.latitude},${loc.longitude}'
          '&travelmode=driving',
        );
      } else {
        mapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=${Uri.encodeComponent(loc.address)}'
          '&travelmode=driving',
        );
      }
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);

      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          'Opening navigation in Google Maps...',
        );
      }
    } catch (e) {
      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          'Could not open navigation: $e',
          isError: true,
        );
      }
    }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 13,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 5),
          Text(
            'Arriving in $etaMinutes min',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF075985),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flight badge
// ─────────────────────────────────────────────────────────────────────────────

class _FlightBadge extends StatelessWidget {
  final String flightNumber;

  const _FlightBadge({required this.flightNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        '✈ $flightNumber',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
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
// NEXT SCHEDULED RIDE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NextRideCard extends StatelessWidget {
  final Ride ride;

  const _NextRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final textLight = isDark ? AppColors.textLightDark : AppColors.textLight;

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
    final statusLabel = RideStatusStyles.getStatusDisplayName(ride.status);

    return Container(
      decoration: AppStyles.primaryCardDecorationOf(context).copyWith(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowXs,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: badge + pickup time
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

            const SizedBox(height: 10),

            // Route summary
            Text(
              '${ride.from.address} → ${ride.to.address}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Client info
            Text(
              ride.clientName,
              style: TextStyle(fontSize: 11.5, color: textLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded Upcoming tab (reuses UpcomingRidesScreen.buildBody directly)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedUpcomingTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmbeddedUpcomingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        final screen = UpcomingRidesScreen();
        return screen.buildBody(context, rideState);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded History tab (shows completed / cancelled rides)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedHistoryTab extends StatelessWidget {
  const _EmbeddedHistoryTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        if (rideState.isLoading) {
          return const Center(child: CircularProgressIndicator());
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
                  'No completed rides yet',
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
      },
    );
  }
}

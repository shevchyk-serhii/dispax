import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/models/location.dart' as loc;
import '../modules/core/models/websocket_event.dart';
import '../modules/core/services/mapbox_service.dart';
import '../modules/core/services/websocket_service.dart';
import '../modules/ride_management/models/ride.dart';
import '../modules/ride_management/services/ride_service.dart';
import '../utils/ride_status_styles.dart';
import '../utils/serial_task_queue.dart';

/// Full-screen map bound to a single [Ride] — the driver's and dispatcher's
/// counterpart to the client's [ClientMapScreen]. Shows the pickup/dropoff
/// markers for exactly this ride plus the assigned driver's live position
/// (WebSocket `LocationUpdated`, with an initial REST fix), instead of
/// self-selecting "the current ride" like the dashboard map tab does.
class RideMapScreen extends StatefulWidget {
  final Ride ride;

  const RideMapScreen({super.key, required this.ride});

  /// Route name so navigation to this screen is observable in widget tests
  /// without mounting the Mapbox platform view.
  static const String routeName = '/ride-map';

  /// Single entry point for opening the ride-bound map. The screen carries the
  /// [Ride] itself and listens to the WebSocket directly, so — unlike
  /// [ClientMapScreen] — it does not read [RideBloc] and needs no
  /// `BlocProvider.value` re-wrapping inside the pushed route.
  static Route<void> route(BuildContext context, {required Ride ride}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => RideMapScreen(ride: ride),
    );
  }

  /// Whether an incoming driver location event belongs to [ride]. Matches by
  /// ride id first (LocationUpdated carries it), falling back to the assigned
  /// driver id. A stray update from another ride/driver must be ignored or it
  /// paints a ghost marker. Static so it is unit-testable without Mapbox.
  @visibleForTesting
  static bool shouldApplyDriverLocation(
    Ride ride, {
    String? eventRideId,
    String? eventDriverId,
  }) {
    if (eventRideId != null) return eventRideId == ride.id;
    return eventDriverId != null && eventDriverId == ride.driverId;
  }

  /// Whether the ride still has a driver actively on the road, i.e. whether
  /// live driver tracking makes sense for it.
  @visibleForTesting
  static bool isLiveTrackable(Ride ride) =>
      ride.driverId != null &&
      (ride.status == RideStatus.assigned ||
          ride.status == RideStatus.confirmed ||
          ride.status == RideStatus.inProgress);

  /// Pure decision for how a lifecycle WebSocket event changes the tracked
  /// ride. Carries ALL the event→state logic so it is unit-testable without
  /// mounting the Mapbox platform view. Returns null when the event does not
  /// concern [ride] or changes nothing.
  ///
  /// Covered events:
  /// * `RideAssigned` — a (re)assignment: the driver may have changed and the
  ///   status becomes assigned. Without this the screen kept filtering
  ///   locations by the OLD driver id after a reassignment, freezing the
  ///   marker on the old driver with his name.
  /// * `RideDetailsUpdated` — carries the ride's current driver (null =
  ///   unassigned); only a driver change matters here.
  /// * `RideConfirmed` / `RideRejected` — separate event types (NOT
  ///   RideStatusChanged): confirm flips the pill to confirmed; reject
  ///   reverts it to requested and unassigns the driver (backend contract).
  /// * `RideStatusChanged` — plain status update for the pill.
  @visibleForTesting
  static RideMapEventDecision? decideRideEvent(
    Ride ride,
    WebSocketEvent event,
  ) {
    if (event.rideId != ride.id) return null;

    if (event.isRideAssigned) {
      final newDriverId = event.driverId;
      final driverChanged = newDriverId != ride.driverId;
      final newStatus = ride.status == RideStatus.assigned
          ? null
          : RideStatus.assigned;
      if (!driverChanged && newStatus == null) return null;
      return RideMapEventDecision(
        status: newStatus,
        driverChanged: driverChanged,
        driverId: newDriverId,
      );
    }

    if (event.isRideDetailsUpdated) {
      final newDriverId = event.driverId;
      if (newDriverId == ride.driverId) return null;
      return RideMapEventDecision(driverChanged: true, driverId: newDriverId);
    }

    if (event.isRideConfirmed) {
      if (ride.status == RideStatus.confirmed) return null;
      return const RideMapEventDecision(status: RideStatus.confirmed);
    }

    if (event.isRideRejected) {
      final driverChanged = ride.driverId != null;
      final newStatus = ride.status == RideStatus.requested
          ? null
          : RideStatus.requested;
      if (!driverChanged && newStatus == null) return null;
      return RideMapEventDecision(
        status: newStatus,
        driverChanged: driverChanged,
        driverId: null,
      );
    }

    if (event.isRideStatusChanged) {
      final newStatus = event.newStatus;
      if (newStatus == null) return null;
      final parsed = RideStatus.fromStringOrNull(newStatus);
      if (parsed == null || parsed == ride.status) return null;
      return RideMapEventDecision(status: parsed);
    }

    return null;
  }

  @override
  State<RideMapScreen> createState() => _RideMapScreenState();
}

/// The outcome of [RideMapScreen.decideRideEvent]: what a lifecycle WebSocket
/// event changes on the tracked ride.
@visibleForTesting
class RideMapEventDecision {
  /// New status for the pill and marker colour; null keeps the current one.
  final RideStatus? status;

  /// True when the assigned driver changed (including unassignment). The
  /// screen must then drop the stale marker/name/location and re-fetch the new
  /// driver's position.
  final bool driverChanged;

  /// The new driver id — meaningful only when [driverChanged]; null means the
  /// ride is now unassigned.
  final String? driverId;

  const RideMapEventDecision({
    this.status,
    this.driverChanged = false,
    this.driverId,
  });
}

class _RideMapScreenState extends State<RideMapScreen> {
  MapboxMap? _mapboxMap;

  // Pickup/dropoff dots live on their own manager so the driver-dot pulse
  // animation never re-creates them (same layering as ClientMapScreen).
  CircleAnnotationManager? _routeCircleManager;
  CircleAnnotationManager? _driverCircleManager;
  CircleAnnotation? _driverCircle;
  PointAnnotationManager? _driverLabelManager;
  PointAnnotation? _driverLabel;

  StreamSubscription? _wsSubscription;
  Timer? _pulseTimer;
  bool _pulseState = false;

  /// Serializes every driver-marker mutation (delete→create replacement,
  /// pulse-tick radius update, clearing on reassign): the replacement is not
  /// atomic, so a concurrent update or pulse tick could otherwise touch an
  /// already-deleted annotation or leave a duplicate dot.
  final SerialTaskQueue _markerQueue = SerialTaskQueue();

  late Ride _ride;
  // Route endpoints with coordinates resolved (geocoded when the ride only
  // carries addresses) — the markers and camera are built from these.
  late loc.Location _from;
  late loc.Location _to;
  RideService? _rideService;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _from = _ride.from;
    _to = _ride.to;
    _listenToWebSocket();
    _startPulse();
    _resolveMissingCoordinates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideService == null) {
      _rideService = RideService(apiClient: context.read<AuthBloc>().apiClient);
      _fetchInitialDriverLocation();
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _startPulse() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      _pulseState = !_pulseState;
      // Queued so a tick can never update an annotation that an in-flight
      // delete→create replacement has just removed.
      unawaited(
        _markerQueue.run(() async {
          final driverCircle = _driverCircle;
          if (driverCircle != null) {
            driverCircle.circleRadius = _pulseState ? 15.0 : 12.0;
            await _driverCircleManager?.update(driverCircle);
          }
        }),
      );
    });
  }

  /// Geocodes the pickup/dropoff addresses when the ride carries no
  /// coordinates (older rides), so the markers and camera still work.
  Future<void> _resolveMissingCoordinates() async {
    if (_from.latitude == null || _from.longitude == null) {
      final coords = await MapboxService.geocodeAddress(_from.address);
      if (coords != null && mounted) {
        setState(() {
          _from = loc.Location(
            address: _from.address,
            latitude: coords[0],
            longitude: coords[1],
          );
        });
      }
    }
    if (_to.latitude == null || _to.longitude == null) {
      final coords = await MapboxService.geocodeAddress(_to.address);
      if (coords != null && mounted) {
        setState(() {
          _to = loc.Location(
            address: _to.address,
            latitude: coords[0],
            longitude: coords[1],
          );
        });
      }
    }
    _redrawRoute();
  }

  /// One REST fetch so the driver dot appears immediately instead of waiting
  /// for the next WebSocket location ping (drivers throttle updates to ~10s).
  Future<void> _fetchInitialDriverLocation() async {
    if (!RideMapScreen.isLiveTrackable(_ride)) return;
    if (_ride.driverLocation != null) return;
    final data = await _rideService?.getDriverProximity(_ride.id);
    if (!mounted || data == null) return;
    final driverLocation = data['driverLocation'];
    final lat = (driverLocation is Map)
        ? (driverLocation['latitude'] as num?)?.toDouble()
        : null;
    final lng = (driverLocation is Map)
        ? (driverLocation['longitude'] as num?)?.toDouble()
        : null;
    final eta = (data['etaMinutes'] as num?)?.toInt();
    if (lat == null || lng == null) return;
    setState(() {
      _ride = _ride.copyWith(
        driverLocation: loc.Location(
          address: '',
          latitude: lat,
          longitude: lng,
        ),
        etaMinutes: eta ?? _ride.etaMinutes,
      );
    });
    _updateDriverMarker(lat, lng);
  }

  void _listenToWebSocket() {
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      _handleDriverLocationEvent(event);
      _handleStatusEvent(event);
    });
  }

  void _handleDriverLocationEvent(WebSocketEvent event) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    if (!event.isLocationUpdated ||
        event.locationType != 'driver' ||
        latitude == null ||
        longitude == null ||
        !RideMapScreen.shouldApplyDriverLocation(
          _ride,
          eventRideId: event.rideId,
          eventDriverId: event.driverId,
        )) {
      return;
    }
    setState(() {
      _ride = _ride.copyWith(
        driverLocation: loc.Location(
          address: '',
          latitude: latitude,
          longitude: longitude,
        ),
      );
    });
    _updateDriverMarker(latitude, longitude);
  }

  void _handleStatusEvent(WebSocketEvent event) {
    final decision = RideMapScreen.decideRideEvent(_ride, event);
    if (decision == null) return;
    setState(() {
      var updated = _ride.copyWith(status: decision.status);
      if (decision.driverChanged) {
        // The old driver's id/name/location are stale the moment the ride is
        // reassigned — clear them or the location filter keeps accepting the
        // OLD driver's pings and the marker freezes on him with his name.
        updated = updated.copyWith(
          driverId: decision.driverId,
          driverName: null,
          driverLocation: null,
        );
      }
      _ride = updated;
    });
    if (decision.driverChanged) {
      _clearDriverMarker();
      // New driver (if any): fetch a fresh fix so the marker reappears
      // immediately instead of waiting for the next ~10s WebSocket ping.
      _fetchInitialDriverLocation();
      return;
    }
    // The dot colour follows the status palette — redraw at the last fix.
    final driverLat = _ride.driverLocation?.latitude;
    final driverLng = _ride.driverLocation?.longitude;
    if (driverLat != null && driverLng != null) {
      _updateDriverMarker(driverLat, driverLng);
    }
  }

  /// Removes the driver dot and name label from the map (used when the ride
  /// is reassigned or the driver is unassigned). Serialized with the other
  /// marker mutations.
  Future<void> _clearDriverMarker() => _markerQueue.run(_clearDriverMarkerNow);

  Future<void> _clearDriverMarkerNow() async {
    final driverCircle = _driverCircle;
    if (driverCircle != null) {
      _driverCircle = null;
      await _driverCircleManager?.delete(driverCircle);
    }
    final driverLabel = _driverLabel;
    if (driverLabel != null) {
      _driverLabel = null;
      await _driverLabelManager?.delete(driverLabel);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _routeCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _driverCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _driverLabelManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _redrawRoute();
    final driverLat = _ride.driverLocation?.latitude;
    final driverLng = _ride.driverLocation?.longitude;
    if (driverLat != null && driverLng != null) {
      _updateDriverMarker(driverLat, driverLng);
    }
  }

  void _redrawRoute() {
    if (_mapboxMap == null || _routeCircleManager == null) return;
    _routeCircleManager?.deleteAll();
    final markers = MapboxService.createRideMarkers(from: _from, to: _to);
    for (final marker in markers) {
      _routeCircleManager?.create(marker);
    }
    _mapboxMap?.setCamera(
      MapboxService.getCameraForRoute(from: _from, to: _to),
    );
  }

  /// Replaces the driver dot/label. The delete→await→create pair below is not
  /// atomic, so it is enqueued: a burst of updates (REST fetch racing the
  /// first WS ping, reconnect replay) can no longer interleave and delete an
  /// already-deleted annotation or leave a duplicate marker.
  Future<void> _updateDriverMarker(double latitude, double longitude) =>
      _markerQueue.run(() => _updateDriverMarkerNow(latitude, longitude));

  Future<void> _updateDriverMarkerNow(double latitude, double longitude) async {
    if (_driverCircleManager == null) return;
    final color = RideStatusStyles.getStatusColorValue(_ride.status);

    final driverCircle = _driverCircle;
    if (driverCircle != null) {
      await _driverCircleManager?.delete(driverCircle);
      _driverCircle = null;
    }
    _driverCircle = await _driverCircleManager?.create(
      MapboxService.createDriverMarker(
        latitude: latitude,
        longitude: longitude,
        color: color,
        radius: _pulseState ? 15.0 : 12.0,
        driverId: _ride.driverId,
      ),
    );

    final name = _ride.driverName;
    final driverLabel = _driverLabel;
    if (driverLabel != null) {
      await _driverLabelManager?.delete(driverLabel);
      _driverLabel = null;
    }
    if (name != null && name.isNotEmpty) {
      _driverLabel = await _driverLabelManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(longitude, latitude)),
          textField: name,
          textSize: 13.0,
          textColor: color,
          textHaloColor: 0xFFFFFFFF,
          textHaloWidth: 2.0,
          textOffset: [0.0, -2.0],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            MapWidget(
              key: const ValueKey('ride_map'),
              // Pin the style explicitly: relying on the SDK default left the
              // map black whenever the style failed to resolve.
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
            ),

            // Top overlay: back button + status pill.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 12),
                    _StatusPill(status: _ride.status),
                  ],
                ),
              ),
            ),

            // Bottom panel: route summary + driver line.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RideSummaryPanel(ride: _ride, from: _from, to: _to),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RideStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = RideStatusStyles.getStatusBackgroundColor(
      status,
      brightness: brightness,
    );
    final fg = RideStatusStyles.getStatusTextColor(
      status,
      brightness: brightness,
    );
    final border = RideStatusStyles.getStatusBorderColor(
      status,
      brightness: brightness,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: RideStatusStyles.getStatusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            RideStatusStyles.getStatusDisplayName(
              status,
              AppLocalizations.of(context)!,
            ),
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

class _RideSummaryPanel extends StatelessWidget {
  final Ride ride;
  final loc.Location from;
  final loc.Location to;

  const _RideSummaryPanel({
    required this.ride,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final etaMinutes = ride.etaMinutes;
    final driverName = ride.driverName;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddressRow(
              color: AppColors.success,
              isSquare: false,
              address: from.address,
            ),
            const SizedBox(height: 8),
            _AddressRow(
              color: AppColors.error,
              isSquare: true,
              address: to.address,
            ),
            if (driverName != null && driverName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (etaMinutes != null)
                    Text(
                      'ETA $etaMinutes min',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Color color;
  final bool isSquare;
  final String address;

  const _AddressRow({
    required this.color,
    required this.isSquare,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isSquare ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../modules/core/models/location.dart' as loc;
import '../modules/core/services/location_service.dart';
import '../modules/core/services/mapbox_service.dart';
import '../modules/core/services/websocket_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';
import '../modules/flight_management/widgets/airport_entry_timer.dart';
import '../modules/flight_management/widgets/airport_checkpoint_progress.dart';
import '../modules/flight_management/muc_checkpoints.dart';
import 'widgets/ride_control_panel.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotationManager? _checkpointAnnotationManager;
  CircleAnnotation? _clientCircleAnnotation;
  PointAnnotation? _clientLabelAnnotation;
  Uint8List? _clientMarkerImage;
  Uint8List? _driverMarkerImage;
  PointAnnotation? _driverSelfAnnotation;
  Timer? _pulseTimer;
  bool _pulseState = false;
  String? _airportCheckpoint;

  StreamSubscription<geo.Position>? _locationSubscription;
  geo.Position? _currentPosition;
  List<Ride> _assignedRides = [];
  Ride? _currentRide;

  final LocationService _locationService = LocationService.instance;
  RideService? _rideService;
  Timer? _locationUpdateTimer;
  Timer? _etaTimer;
  StreamSubscription? _wsSubscription;
  String? _geofenceOverlayMessage;
  Timer? _geofenceOverlayTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideService ??= RideService(apiClient: context.read<AuthBloc>().apiClient);
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _listenToGeofenceEvents();
    _startPulse();
    // Sync rides from current BLoC state immediately (BlocListener only fires on changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRidesFromBloc();
      _refreshEta();
    });
    _etaTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshEta(),
    );
  }

  Future<void> _refreshEta() async {
    final rideService = _rideService;
    final ride = _currentRide;
    if (!mounted || rideService == null || ride == null) return;
    final data = await rideService.getDriverProximity(ride.id);
    if (!mounted) return;
    final eta = data?['etaMinutes'] as int?;
    final currentRide = _currentRide;
    if (eta != null && currentRide != null) {
      setState(() {
        _currentRide = currentRide.copyWith(etaMinutes: eta);
      });
    }
  }

  void _syncRidesFromBloc() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    final rideState = context.read<RideBloc>().state;
    final user = authState.user;
    if (!authState.isAuthenticated || user == null) return;

    final driverRides = rideState.rides
        .where(
          (ride) =>
              ride.driverId == user.id &&
              (ride.status == RideStatus.assigned ||
                  ride.status == RideStatus.inProgress),
        )
        .toList();

    final currentRide =
        driverRides
            .where((r) => r.status == RideStatus.inProgress)
            .firstOrNull ??
        (driverRides.where((r) => r.status == RideStatus.assigned).toList()
              ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime)))
            .firstOrNull;

    setState(() {
      _assignedRides = driverRides;
      _currentRide = currentRide;
    });
    _updateMapMarkers();
  }

  void _startPulse() {
    // 1s interval (was 700ms): each tick fires async Mapbox bridge update() calls,
    // so a slower pulse roughly halves that churn while staying visibly animated.
    _pulseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Nothing to animate yet — skip the bridge round-trips entirely.
      if (_clientLabelAnnotation == null && _driverSelfAnnotation == null) {
        return;
      }
      _pulseState = !_pulseState;
      final size = _pulseState ? 2.0 : 1.5;
      final clientLabel = _clientLabelAnnotation;
      if (clientLabel != null) {
        clientLabel.iconSize = size;
        _pointAnnotationManager?.update(clientLabel);
      }
      final driverSelf = _driverSelfAnnotation;
      if (driverSelf != null) {
        driverSelf.iconSize = size;
        _pointAnnotationManager?.update(driverSelf);
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _etaTimer?.cancel();
    _wsSubscription?.cancel();
    _geofenceOverlayTimer?.cancel();
    _pulseTimer?.cancel();
    // Release Mapbox annotations so markers don't linger on the shared native map.
    _pointAnnotationManager?.deleteAll();
    _circleAnnotationManager?.deleteAll();
    _checkpointAnnotationManager?.deleteAll();
    _locationService.dispose();
    super.dispose();
  }

  void _listenToGeofenceEvents() {
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;

      if (event.isGeofenceTriggered) {
        final geofenceName = event.geofenceName ?? 'Unknown zone';
        final isEntry = event.alertType == 'entry';
        final message = isEntry
            ? 'Entered $geofenceName'
            : 'Left $geofenceName';
        setState(() => _geofenceOverlayMessage = message);
        _geofenceOverlayTimer?.cancel();
        _geofenceOverlayTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _geofenceOverlayMessage = null);
        });
      }

      final eventLat = event.latitude;
      final eventLng = event.longitude;
      if (event.isLocationUpdated &&
          event.locationType == 'client' &&
          eventLat != null &&
          eventLng != null) {
        final rideId = event.rideId;
        final ride = _currentRide;
        if (ride != null && (rideId == null || rideId == ride.id)) {
          setState(() {
            _currentRide = ride.copyWith(
              clientLocation: loc.Location(
                address: '',
                latitude: eventLat,
                longitude: eventLng,
              ),
            );
          });
          _updateClientMarker(eventLat, eventLng);
        }
      }

      final checkpointRide = _currentRide;
      if (event.isAirportCheckpointReached &&
          checkpointRide != null &&
          event.rideId == checkpointRide.id) {
        setState(() {
          _airportCheckpoint = event.checkpointType;
          _currentRide = checkpointRide.copyWith(
            airportCheckpoint: event.checkpointType,
          );
        });
        _renderCheckpointMarkers();
      }
    });
  }

  Future<void> _renderCheckpointMarkers() async {
    final checkpointManager = _checkpointAnnotationManager;
    if (checkpointManager == null) return;

    await checkpointManager.deleteAll();

    final currentOrdinal = MucCheckpoints.ordinal(_airportCheckpoint);

    for (int i = 0; i < MucCheckpoints.chain.length; i++) {
      final cp = MucCheckpoints.chain[i];
      final int color;
      if (i < currentOrdinal) {
        color = 0xFF4CAF50; // completed - green
      } else if (i == currentOrdinal) {
        color = 0xFFFF9800; // active - amber
      } else {
        color = 0xFF9E9E9E; // pending - grey
      }

      await checkpointManager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(cp.lon, cp.lat)),
          circleRadius: 12.0,
          circleColor: color,
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
          circleOpacity: 0.85,
        ),
      );
    }
  }

  Future<void> _updateClientMarker(double latitude, double longitude) async {
    final pointManager = _pointAnnotationManager;
    if (pointManager == null) return;

    final clientCircle = _clientCircleAnnotation;
    if (clientCircle != null) {
      await _circleAnnotationManager?.delete(clientCircle);
      _clientCircleAnnotation = null;
    }
    final clientLabel = _clientLabelAnnotation;
    if (clientLabel != null) {
      await pointManager.delete(clientLabel);
      _clientLabelAnnotation = null;
    }

    _clientMarkerImage ??= (await rootBundle.load(
      'assets/client_marker.png',
    )).buffer.asUint8List();

    _clientLabelAnnotation = await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(longitude, latitude)),
        image: _clientMarkerImage,
        iconSize: 1.5,
        textField: _currentRide?.clientName,
        textSize: 13.0,
        textColor: 0xFF1B5E20,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2.0,
        textOffset: [0.0, -2.5],
      ),
    );
  }

  Future<void> _initializeLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
      _sendLocationUpdate();
    }

    final started = await _locationService.startLocationTracking();
    if (started) {
      _locationSubscription = _locationService.positionStream.listen((
        geo.Position position,
      ) {
        final isFirst = _currentPosition == null;
        setState(() {
          _currentPosition = position;
        });
        _updateCurrentLocationMarker();
        _sendLocationUpdate();
        // Center map on first real GPS fix if map was created without position
        final mapboxMap = _mapboxMap;
        if (isFirst && mapboxMap != null && _currentRide == null) {
          mapboxMap.setCamera(
            MapboxService.createCameraOptions(
              latitude: position.latitude,
              longitude: position.longitude,
              zoom: 15.0,
            ),
          );
        }
      });
    }

    // Fallback: send location every 30s even without movement
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocationUpdate();
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _checkpointAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    await MapboxService.addDefaultImages(mapboxMap);

    final currentPosition = _currentPosition;
    if (currentPosition != null) {
      final cameraOptions = MapboxService.createCameraOptions(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        zoom: 15.0,
      );
      await mapboxMap.setCamera(cameraOptions);
    }

    _updateMapMarkers();
    // Re-render checkpoint markers if we already have checkpoint state
    if (_airportCheckpoint != null) {
      _renderCheckpointMarkers();
    }
  }

  Future<void> _updateCurrentLocationMarker() async {
    if (_mapboxMap == null || _currentPosition == null) return;

    final driverName = context.read<AuthBloc>().state.user?.name;

    final existingDriverSelf = _driverSelfAnnotation;
    if (existingDriverSelf != null) {
      await _pointAnnotationManager?.delete(existingDriverSelf);
      _driverSelfAnnotation = null;
    }

    _driverMarkerImage ??= (await rootBundle.load(
      'assets/driver_marker.png',
    )).buffer.asUint8List();

    final currentPosition = _currentPosition;
    if (currentPosition == null) return;

    _driverSelfAnnotation = await _pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            currentPosition.longitude,
            currentPosition.latitude,
          ),
        ),
        image: _driverMarkerImage,
        iconSize: 2.0,
        textField: driverName,
        textSize: 13.0,
        textColor: 0xFF0D47A1,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2.0,
        textOffset: [0.0, 2.5],
      ),
    );

    final clientLocation = _currentRide?.clientLocation;
    final clientLat = clientLocation?.latitude;
    final clientLng = clientLocation?.longitude;
    if (clientLat != null && clientLng != null) {
      await _updateClientMarker(clientLat, clientLng);
    }
  }

  void _updateMapMarkers() {
    final circleManager = _circleAnnotationManager;
    if (_mapboxMap == null || circleManager == null) return;

    circleManager.deleteAll();
    _clientCircleAnnotation = null;
    _pointAnnotationManager?.deleteAll();
    _clientLabelAnnotation = null;
    _driverSelfAnnotation = null;

    _updateCurrentLocationMarker();

    // Background rides (not the priority one) — small grey markers
    for (final ride in _assignedRides) {
      if (ride.id == _currentRide?.id) continue;
      final fromLat = ride.from.latitude;
      final fromLng = ride.from.longitude;
      if (fromLat != null && fromLng != null) {
        circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(fromLng, fromLat)),
            circleRadius: 5.0,
            circleColor: 0xFF9E9E9E,
            circleStrokeWidth: 1.5,
            circleStrokeColor: 0xFFFFFFFF,
          ),
        );
      }
      final toLat = ride.to.latitude;
      final toLng = ride.to.longitude;
      if (toLat != null && toLng != null) {
        circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(toLng, toLat)),
            circleRadius: 5.0,
            circleColor: 0xFF9E9E9E,
            circleStrokeWidth: 1.5,
            circleStrokeColor: 0xFFFFFFFF,
          ),
        );
      }
    }

    final currentRide = _currentRide;
    if (currentRide == null) return;

    // Priority ride: large pickup marker (client location), smaller drop-off
    final fromLat = currentRide.from.latitude;
    final fromLng = currentRide.from.longitude;
    if (fromLat != null && fromLng != null) {
      circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(fromLng, fromLat)),
          circleRadius: 16.0,
          circleColor: 0xFF4CAF50,
          circleStrokeWidth: 3.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }

    final toLat = currentRide.to.latitude;
    final toLng = currentRide.to.longitude;
    if (toLat != null && toLng != null) {
      circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(toLng, toLat)),
          circleRadius: 10.0,
          circleColor: 0xFFF44336,
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }

    // Real-time client location (if shared via WebSocket)
    final clientLat = currentRide.clientLocation?.latitude;
    final clientLng = currentRide.clientLocation?.longitude;
    if (clientLat != null && clientLng != null) {
      _updateClientMarker(clientLat, clientLng);
    }

    // Focus camera: pickup coords → driver position → Munich (default)
    final pickup = currentRide.from;
    final pickupLat = pickup.latitude;
    final pickupLng = pickup.longitude;
    final currentPosition = _currentPosition;
    if (pickupLat != null && pickupLng != null) {
      _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(pickupLng, pickupLat)),
          zoom: 14.0,
        ),
      );
    } else if (currentPosition != null) {
      _mapboxMap?.setCamera(
        MapboxService.createCameraOptions(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          zoom: 14.0,
        ),
      );
    } else {
      // Munich fallback when no coordinates available yet
      _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(11.5820, 48.1351)),
          zoom: 12.0,
        ),
      );
    }
  }

  DateTime? _lastLocationSent;
  double? _lastSentLat;
  double? _lastSentLng;

  void _sendLocationUpdate() {
    final currentPosition = _currentPosition;
    if (currentPosition == null) return;

    // Throttle: don't send more than once per 10 seconds
    final now = DateTime.now();
    final lastLocationSent = _lastLocationSent;
    if (lastLocationSent != null &&
        now.difference(lastLocationSent).inSeconds < 10) {
      return;
    }

    // Skip when the driver hasn't meaningfully moved (< 25m) since the last send:
    // a parked driver shouldn't keep re-posting the same coordinate every 30s.
    final lastSentLat = _lastSentLat;
    final lastSentLng = _lastSentLng;
    if (lastSentLat != null && lastSentLng != null) {
      final moved = geo.Geolocator.distanceBetween(
        lastSentLat,
        lastSentLng,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      if (moved < 25) return;
    }

    final authState = context.read<AuthBloc>().state;
    final user = authState.user;
    if (!authState.isAuthenticated || user == null) return;

    _lastLocationSent = now;
    _lastSentLat = currentPosition.latitude;
    _lastSentLng = currentPosition.longitude;

    _rideService?.updateDriverLocation(
      user.id,
      currentPosition.latitude,
      currentPosition.longitude,
    );
  }

  void _updateRideStatus(Ride ride, RideStatus newStatus) {
    context.read<RideBloc>().add(
      RideStatusUpdateRequested(rideId: ride.id, status: newStatus),
    );
  }

  void _onAirportEntryTimeReached(Ride ride) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Time to depart to airport for ride with ${ride.clientName}!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Start Ride',
          textColor: Colors.white,
          onPressed: () => _updateRideStatus(ride, RideStatus.inProgress),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed Mapbox map: light tiles are visible under the status bar.
    // Use SystemUiOverlayStyle.dark so the clock/icons remain legible over
    // the light map background. The floating info panel does not reach the
    // very top edge, so there is no dark header to justify .light icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: BlocListener<RideBloc, RideState>(
          listener: (context, state) {
            final authState = context.read<AuthBloc>().state;
            final user = authState.user;
            if (authState.isAuthenticated && user != null) {
              final driverRides = state.rides
                  .where(
                    (ride) =>
                        ride.driverId == user.id &&
                        (ride.status == RideStatus.assigned ||
                            ride.status == RideStatus.inProgress),
                  )
                  .toList();

              // inProgress first, then earliest assigned
              final currentRide =
                  driverRides
                      .where((r) => r.status == RideStatus.inProgress)
                      .firstOrNull ??
                  (driverRides
                          .where((r) => r.status == RideStatus.assigned)
                          .toList()
                        ..sort(
                          (a, b) =>
                              a.pickupDateTime.compareTo(b.pickupDateTime),
                        ))
                      .firstOrNull;

              if (driverRides != _assignedRides ||
                  currentRide?.id != _currentRide?.id) {
                setState(() {
                  _assignedRides = driverRides;
                  _currentRide = currentRide;
                });
                _updateMapMarkers();
                _refreshEta();
              }
            }
          },
          child: Stack(
            children: [
              MapWidget(
                key: const ValueKey('driver_map'),
                styleUri: MapboxStyles.MAPBOX_STREETS,
                onMapCreated: _onMapCreated,
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildInfoPanel(),

                    if (_geofenceOverlayMessage != null)
                      _buildGeofenceOverlay(),

                    if (_assignedRides.any(
                      (ride) =>
                          ride.isAirportTransfer &&
                          ride.status == RideStatus.assigned,
                    ))
                      ..._assignedRides
                          .where(
                            (ride) =>
                                ride.isAirportTransfer &&
                                ride.status == RideStatus.assigned,
                          )
                          .map(
                            (ride) => AirportEntryTimer(
                              ride: ride,
                              onEntryTimeReached: () =>
                                  _onAirportEntryTimeReached(ride),
                            ),
                          ),
                  ],
                ),
              ),

              if (_currentRide != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildRideControlPanel(),
                ),

              Positioned(
                bottom: _currentRide != null ? 260 : 100,
                right: 16,
                child: _buildControlButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceOverlay() {
    final message = _geofenceOverlayMessage ?? '';
    final isEntry = message.startsWith('Entered');
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: isEntry ? AppColors.success : AppColors.error,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isEntry ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _geofenceOverlayMessage = null),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.drive_eta,
                color: AppColors.driverColor,
                size: AppDimensions.iconMedium,
              ),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Driver Dashboard',
                style: AppStyles.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Rides: ${_assignedRides.length}',
                style: AppStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_currentRide != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingSmall,
                    vertical: AppDimensions.paddingXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.driverColor,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Text(
                    'IN PROGRESS',
                    style: AppStyles.labelSmall.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideControlPanel() {
    final ride = _currentRide;
    if (ride == null) return const SizedBox.shrink();

    return RideControlPanel(
      ride: ride,
      onStartRide: () => _updateRideStatus(ride, RideStatus.inProgress),
      onCompleteRide: () => _updateRideStatus(ride, RideStatus.completed),
      airportCheckpoint: ride.isAirportTransfer && ride.isArrival
          ? AirportCheckpointProgress(
              currentCheckpoint: _airportCheckpoint ?? ride.airportCheckpoint,
            )
          : null,
    );
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'center_location',
          onPressed: _centerOnCurrentLocation,
          backgroundColor: AppColors.driverColor,
          child: const Icon(Icons.my_location, color: AppColors.textOnPrimary),
        ),

        if (_assignedRides.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          FloatingActionButton(
            heroTag: 'show_all_rides',
            onPressed: _showAllRides,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.list,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ],
    );
  }

  void _centerOnCurrentLocation() {
    final mapboxMap = _mapboxMap;
    final currentPosition = _currentPosition;
    if (mapboxMap != null && currentPosition != null) {
      final cameraOptions = MapboxService.createCameraOptions(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        zoom: 16.0,
      );
      mapboxMap.setCamera(cameraOptions);
    }
  }

  void _showAllRides() {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || _assignedRides.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final ride in _assignedRides) {
      final fromLat = ride.from.latitude;
      final fromLng = ride.from.longitude;
      if (fromLat != null && fromLng != null) {
        minLat = minLat > fromLat ? fromLat : minLat;
        maxLat = maxLat < fromLat ? fromLat : maxLat;
        minLng = minLng > fromLng ? fromLng : minLng;
        maxLng = maxLng < fromLng ? fromLng : maxLng;
      }

      final toLat = ride.to.latitude;
      final toLng = ride.to.longitude;
      if (toLat != null && toLng != null) {
        minLat = minLat > toLat ? toLat : minLat;
        maxLat = maxLat < toLat ? toLat : maxLat;
        minLng = minLng > toLng ? toLng : minLng;
        maxLng = maxLng < toLng ? toLng : maxLng;
      }
    }

    final currentPosition = _currentPosition;
    if (currentPosition != null) {
      final lat = currentPosition.latitude;
      final lng = currentPosition.longitude;
      minLat = minLat > lat ? lat : minLat;
      maxLat = maxLat < lat ? lat : maxLat;
      minLng = minLng > lng ? lng : minLng;
      maxLng = maxLng < lng ? lng : maxLng;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: 12.0,
    );

    mapboxMap.setCamera(cameraOptions);
  }
}

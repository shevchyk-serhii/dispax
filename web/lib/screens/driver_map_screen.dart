import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../modules/core/services/location_service.dart';
import '../modules/core/services/mapbox_service.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/date_utils.dart';
import '../modules/flight_management/widgets/airport_entry_timer.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;

  StreamSubscription<geo.Position>? _locationSubscription;
  geo.Position? _currentPosition;
  List<Ride> _assignedRides = [];
  Ride? _currentRide;

  final LocationService _locationService = LocationService.instance;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
    }

    final started = await _locationService.startLocationTracking();
    if (started) {
      _locationSubscription = _locationService.positionStream.listen((geo.Position position) {
        setState(() {
          _currentPosition = position;
        });
        _updateCurrentLocationMarker();
        _sendLocationUpdate();
      });
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();

    await MapboxService.addDefaultImages(mapboxMap);

    if (_currentPosition != null) {
      final cameraOptions = MapboxService.createCameraOptions(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        zoom: 15.0,
      );
      await mapboxMap.setCamera(cameraOptions);
    }

    _updateMapMarkers();
  }

  void _updateCurrentLocationMarker() {
    if (_mapboxMap == null || _currentPosition == null) return;

    _circleAnnotationManager?.deleteAll();

    final marker = MapboxService.createLocationMarker(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      color: 'blue',
      radius: 15.0,
    );

    _circleAnnotationManager?.create(marker);
  }

  void _updateMapMarkers() {
    if (_mapboxMap == null || _circleAnnotationManager == null) return;

    for (final ride in _assignedRides) {
      final rideMarkers = MapboxService.createRideMarkers(
        from: ride.from,
        to: ride.to,
      );

      for (final marker in rideMarkers) {
        _circleAnnotationManager?.create(marker);
      }
    }

    if (_currentRide != null) {
      final cameraOptions = MapboxService.getCameraForRoute(
        from: _currentRide!.from,
        to: _currentRide!.to,
        currentPosition: _currentPosition,
      );

      _mapboxMap?.setCamera(cameraOptions);
    }
  }

  DateTime? _lastLocationSent;

  void _sendLocationUpdate() {
    if (_currentPosition == null) return;
    if (_assignedRides.isEmpty) return;

    // Throttle: don't send more than once per 10 seconds
    final now = DateTime.now();
    if (_lastLocationSent != null &&
        now.difference(_lastLocationSent!).inSeconds < 10) {
      return;
    }
    _lastLocationSent = now;

    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated || authState.user == null) return;

    final rideService = RideService();
    rideService.updateDriverLocation(
      authState.user!.id,
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  void _updateRideStatus(Ride ride, RideStatus newStatus) {

    context.read<RideBloc>().add(RideStatusUpdateRequested(
      rideId: ride.id,
      status: newStatus,
    ));
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
    return Scaffold(
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {

          final authState = context.read<AuthBloc>().state;
          if (authState.isAuthenticated && authState.user != null) {
            final driverRides = state.rides.where((ride) =>
              ride.driverId == authState.user!.id &&
              (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress)
            ).toList();

            final currentRide = driverRides.where((ride) =>
              ride.status == RideStatus.inProgress
            ).firstOrNull;

            if (driverRides != _assignedRides || currentRide != _currentRide) {
              setState(() {
                _assignedRides = driverRides;
                _currentRide = currentRide;
              });
              _updateMapMarkers();
            }
          }
        },
        child: Stack(
          children: [

            MapWidget(
              key: const ValueKey('driver_map'),
              onMapCreated: _onMapCreated,
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildInfoPanel(),

                  if (_assignedRides.any((ride) => ride.isAirportTransfer && ride.status == RideStatus.assigned))
                    ..._assignedRides
                        .where((ride) => ride.isAirportTransfer && ride.status == RideStatus.assigned)
                        .map((ride) => AirportEntryTimer(
                              ride: ride,
                              onEntryTimeReached: () => _onAirportEntryTimeReached(ride),
                            )),
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
              bottom: _currentRide != null ? 200 : 100,
              right: 16,
              child: _buildControlButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drive_eta, color: AppColors.driverColor, size: AppDimensions.iconMedium),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Driver Dashboard',
                style: AppStyles.titleMedium.copyWith(color: AppColors.textOnPrimary),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Rides: ${_assignedRides.length}',
                style: AppStyles.bodyMedium.copyWith(color: AppColors.textOnPrimary.withAlpha(204)),
              ),
              if (_currentRide != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingSmall,
                    vertical: AppDimensions.paddingXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.driverColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  child: Text(
                    'IN PROGRESS',
                    style: AppStyles.labelSmall.copyWith(color: AppColors.textOnPrimary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideControlPanel() {
    if (_currentRide == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.radiusLarge),
          topRight: Radius.circular(AppDimensions.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          Row(
            children: [
              Expanded(
                child: Text(
                  _currentRide!.clientName,
                  style: AppStyles.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingSmall,
                  vertical: AppDimensions.paddingXSmall,
                ),
                decoration: BoxDecoration(
                  color: _getRideStatusColor(_currentRide!.status),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  _currentRide!.statusDisplayName,
                  style: AppStyles.labelSmall.copyWith(color: AppColors.textOnPrimary),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.textSecondary, size: AppDimensions.iconSmall),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                AppDateUtils.formatDateTime(_currentRide!.pickupDateTime),
                style: AppStyles.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          Row(
            children: [
              Icon(Icons.route, color: AppColors.textSecondary, size: AppDimensions.iconSmall),
              const SizedBox(width: AppDimensions.paddingSmall),
              Expanded(
                child: Text(
                  '${_currentRide!.from.address} → ${_currentRide!.to.address}',
                  style: AppStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (_currentRide!.isAirportTransfer) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              children: [
                Icon(Icons.flight, color: AppColors.textSecondary, size: AppDimensions.iconSmall),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  _currentRide!.fullFlightInfo,
                  style: AppStyles.bodyMedium,
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.paddingLarge),

          if (_currentRide!.status == RideStatus.assigned)
            ElevatedButton(
              onPressed: () => _updateRideStatus(_currentRide!, RideStatus.inProgress),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Start Ride'),
            )
          else if (_currentRide!.status == RideStatus.inProgress)
            ElevatedButton(
              onPressed: () => _updateRideStatus(_currentRide!, RideStatus.completed),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clientColor,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Complete Ride'),
            ),
        ],
      ),
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
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.list, color: AppColors.textOnPrimary),
          ),
        ],
      ],
    );
  }

  void _centerOnCurrentLocation() {
    if (_mapboxMap != null && _currentPosition != null) {
      final cameraOptions = MapboxService.createCameraOptions(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        zoom: 16.0,
      );
      _mapboxMap!.setCamera(cameraOptions);
    }
  }

  void _showAllRides() {

    if (_mapboxMap == null || _assignedRides.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final ride in _assignedRides) {
      if (ride.from.latitude != null && ride.from.longitude != null) {
        minLat = minLat > ride.from.latitude! ? ride.from.latitude! : minLat;
        maxLat = maxLat < ride.from.latitude! ? ride.from.latitude! : maxLat;
        minLng = minLng > ride.from.longitude! ? ride.from.longitude! : minLng;
        maxLng = maxLng < ride.from.longitude! ? ride.from.longitude! : maxLng;
      }

      if (ride.to.latitude != null && ride.to.longitude != null) {
        minLat = minLat > ride.to.latitude! ? ride.to.latitude! : minLat;
        maxLat = maxLat < ride.to.latitude! ? ride.to.latitude! : maxLat;
        minLng = minLng > ride.to.longitude! ? ride.to.longitude! : minLng;
        maxLng = maxLng < ride.to.longitude! ? ride.to.longitude! : maxLng;
      }
    }

    if (_currentPosition != null) {
      minLat = minLat > _currentPosition!.latitude ? _currentPosition!.latitude : minLat;
      maxLat = maxLat < _currentPosition!.latitude ? _currentPosition!.latitude : maxLat;
      minLng = minLng > _currentPosition!.longitude ? _currentPosition!.longitude : minLng;
      maxLng = maxLng < _currentPosition!.longitude ? _currentPosition!.longitude : maxLng;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: 12.0,
    );

    _mapboxMap!.setCamera(cameraOptions);
  }

  Color _getRideStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.assigned:
        return AppColors.primary;
      case RideStatus.inProgress:
        return AppColors.driverColor;
      case RideStatus.completed:
        return AppColors.clientColor;
      default:
        return AppColors.primary;
    }
  }
}
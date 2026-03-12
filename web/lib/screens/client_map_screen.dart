import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../modules/core/models/location.dart' as loc;
import '../modules/core/services/location_service.dart';
import '../modules/core/services/mapbox_service.dart';
import '../modules/core/models/websocket_event.dart';
import '../modules/core/services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/date_utils.dart';

class ClientMapScreen extends StatefulWidget {
  const ClientMapScreen({super.key});

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  MapboxMap? _mapboxMap;
  // ignore: unused_field
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;

  StreamSubscription<geo.Position>? _locationSubscription;
  StreamSubscription? _wsSubscription;
  geo.Position? _currentPosition;
  Ride? _activeRide;

  final LocationService _locationService = LocationService.instance;
  bool _sharingLocation = false;
  final RideService _rideService = RideService();
  String? _approachingBannerMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _wsSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  void _listenToWebSocket() {
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted || _activeRide == null) return;

      if (event.isLocationUpdated &&
          event.locationType == 'driver' &&
          event.driverId == _activeRide!.driverId &&
          event.latitude != null &&
          event.longitude != null) {
        setState(() {
          _activeRide = _activeRide!.copyWith(
            driverLocation: loc.Location(
              address: '',
              latitude: event.latitude,
              longitude: event.longitude,
            ),
          );
        });
        _updateMapMarkers();

        // Check if driver is approaching (< 500m)
        if (_currentPosition != null) {
          final distance = geo.Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            event.latitude!,
            event.longitude!,
          );
          if (distance < 500 && !_driverApproachingShown) {
            _driverApproachingShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your driver is approaching! ~${distance.toInt()}m',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 8),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      _handleDriverApproachingEvent(event);
    });
  }

  void _handleDriverApproachingEvent(WebSocketEvent event) {
    if (!event.isDriverApproaching) return;

    final distance = event.distanceMeters ?? 0;
    String message;
    if (distance <= 100) {
      message = 'Your driver has arrived!';
    } else if (distance <= 500) {
      message = 'Your driver is nearby!';
    } else {
      final km = (distance / 1000).toStringAsFixed(1);
      message = 'Your driver is about ${km}km away';
    }
    setState(() => _approachingBannerMessage = message);
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

        // Share client location if toggle is on
        if (_sharingLocation && _activeRide != null) {
          _rideService.updateClientLocation(
            _activeRide!.id,
            position.latitude,
            position.longitude,
          );
        }
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
      radius: 12.0,
    );

    _circleAnnotationManager?.create(marker);
  }

  void _updateMapMarkers() {
    if (_mapboxMap == null || _circleAnnotationManager == null) return;

    if (_activeRide != null) {
      final rideMarkers = MapboxService.createRideMarkers(
        from: _activeRide!.from,
        to: _activeRide!.to,
      );

      for (final marker in rideMarkers) {
        _circleAnnotationManager?.create(marker);
      }

      if (_activeRide!.driverLocation != null &&
          _activeRide!.driverLocation!.latitude != null &&
          _activeRide!.driverLocation!.longitude != null) {
        final driverMarker = MapboxService.createDriverMarker(
          latitude: _activeRide!.driverLocation!.latitude!,
          longitude: _activeRide!.driverLocation!.longitude!,
          driverId: _activeRide!.driverId?.toString(),
        );
        _circleAnnotationManager?.create(driverMarker);
      }

      final cameraOptions = MapboxService.getCameraForRoute(
        from: _activeRide!.from,
        to: _activeRide!.to,
        currentPosition: _currentPosition,
      );

      _mapboxMap?.setCamera(cameraOptions);
    }
  }

  bool _driverApproachingShown = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {

          final authState = context.read<AuthBloc>().state;
          if (authState.isAuthenticated && authState.user != null) {
            final activeRide = state.rides.where((ride) =>
              ride.clientId == authState.user!.id &&
              (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress)
            ).firstOrNull;

            if (activeRide != _activeRide) {
              setState(() {
                _activeRide = activeRide;
              });
              _updateMapMarkers();
            }
          }
        },
        child: Stack(
          children: [

            MapWidget(
              key: const ValueKey('client_map'),
              onMapCreated: _onMapCreated,
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildInfoPanel(),
                  if (_approachingBannerMessage != null)
                    _buildApproachingBanner(),
                ],
              ),
            ),

            Positioned(
              bottom: 100,
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
              Icon(Icons.location_on, color: AppColors.clientColor, size: AppDimensions.iconMedium),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Your Location',
                style: AppStyles.titleMedium.copyWith(color: AppColors.textOnPrimary),
              ),
            ],
          ),

          if (_activeRide != null) ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildActiveRideInfo(),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildLocationSharingToggle(),
          ] else ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'No active ride',
              style: AppStyles.bodyMedium.copyWith(color: AppColors.textOnPrimary.withAlpha(204)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSharingToggle() {
    return Row(
      children: [
        Icon(
          _sharingLocation ? Icons.location_on : Icons.location_off,
          color: _sharingLocation ? AppColors.success : AppColors.textOnPrimary.withAlpha(150),
          size: AppDimensions.iconSmall,
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Expanded(
          child: Text(
            'Share my location',
            style: AppStyles.bodySmall.copyWith(color: AppColors.textOnPrimary),
          ),
        ),
        Switch(
          value: _sharingLocation,
          onChanged: (value) {
            setState(() => _sharingLocation = value);
            if (value && _currentPosition != null && _activeRide != null) {
              _rideService.updateClientLocation(
                _activeRide!.id,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }
          },
          activeColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildActiveRideInfo() {
    if (_activeRide == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingSmall,
            vertical: AppDimensions.paddingXSmall,
          ),
          decoration: BoxDecoration(
            color: _getRideStatusColor(_activeRide!.status),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: Text(
            _activeRide!.statusDisplayName,
            style: AppStyles.labelSmall.copyWith(color: AppColors.textOnPrimary),
          ),
        ),

        const SizedBox(height: AppDimensions.paddingMedium),

        Row(
          children: [
            Icon(Icons.schedule, color: AppColors.textOnPrimary, size: AppDimensions.iconSmall),
            const SizedBox(width: AppDimensions.paddingSmall),
            Text(
              'Pickup: ${AppDateUtils.formatDateTime(_activeRide!.pickupDateTime)}',
              style: AppStyles.bodySmall.copyWith(color: AppColors.textOnPrimary),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.paddingSmall),

        Row(
          children: [
            Icon(Icons.route, color: AppColors.textOnPrimary, size: AppDimensions.iconSmall),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(
              child: Text(
                '${_activeRide!.from.address} -> ${_activeRide!.to.address}',
                style: AppStyles.bodySmall.copyWith(color: AppColors.textOnPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        if (_activeRide!.driverName != null) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          Row(
            children: [
              Icon(Icons.person, color: AppColors.textOnPrimary, size: AppDimensions.iconSmall),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Driver: ${_activeRide!.driverName}',
                style: AppStyles.bodySmall.copyWith(color: AppColors.textOnPrimary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildApproachingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMedium),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
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
          const Icon(Icons.directions_car, color: Colors.white, size: 20),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              _approachingBannerMessage!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _approachingBannerMessage = null),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
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
          backgroundColor: AppColors.clientColor,
          child: const Icon(Icons.my_location, color: AppColors.textOnPrimary),
        ),

        if (_activeRide != null) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          FloatingActionButton(
            heroTag: 'center_route',
            onPressed: _centerOnRoute,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.route, color: AppColors.textOnPrimary),
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

  void _centerOnRoute() {
    if (_mapboxMap != null && _activeRide != null) {
      final cameraOptions = MapboxService.getCameraForRoute(
        from: _activeRide!.from,
        to: _activeRide!.to,
        currentPosition: _currentPosition,
      );
      _mapboxMap!.setCamera(cameraOptions);
    }
  }

  Color _getRideStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.assigned:
        return AppColors.primary;
      case RideStatus.inProgress:
        return AppColors.clientColor;
      case RideStatus.completed:
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }
}

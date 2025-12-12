import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/core/services/location_service.dart';
import '../modules/core/services/mapbox_service.dart';
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
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  
  StreamSubscription<geo.Position>? _locationSubscription;
  geo.Position? _currentPosition;
  Ride? _activeRide;
  
  final LocationService _locationService = LocationService.instance;
  Timer? _driverLocationTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _driverLocationTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // Get current location
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
    }

    // Start location tracking
    final started = await _locationService.startLocationTracking();
    if (started) {
      _locationSubscription = _locationService.positionStream.listen((geo.Position position) {
        setState(() {
          _currentPosition = position;
        });
        _updateCurrentLocationMarker();
      });
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Initialize annotation managers
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    
    // Add markers
    await MapboxService.addDefaultImages(mapboxMap);
    
    // Set initial camera
    if (_currentPosition != null) {
      final cameraOptions = MapboxService.createCameraOptions(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        zoom: 15.0,
      );
      await mapboxMap.setCamera(cameraOptions);
    }
    
    _updateMapMarkers();
    _startDriverLocationUpdates();
  }

  void _updateCurrentLocationMarker() {
    if (_mapboxMap == null || _currentPosition == null) return;
    
    _circleAnnotationManager?.deleteAll();
    
    // Add markers
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
    
    // Clear markers
    // If there is
    if (_activeRide != null) {
      final rideMarkers = MapboxService.createRideMarkers(
        from: _activeRide!.from,
        to: _activeRide!.to,
      );
      
      for (final marker in rideMarkers) {
        _circleAnnotationManager?.create(marker);
      }
      
      // If there is
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
      
      // Set initial camera
      final cameraOptions = MapboxService.getCameraForRoute(
        from: _activeRide!.from,
        to: _activeRide!.to,
        currentPosition: _currentPosition,
      );
      
      _mapboxMap?.setCamera(cameraOptions);
    }
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer?.cancel();
    
    if (_activeRide != null && MapboxService.isRideInProgress(_activeRide!)) {
      _driverLocationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        // In real app, this would send location to server
        _updateDriverLocation();
      });
    }
  }

  void _updateDriverLocation() {
    // Заглушка для обновления местоположения водителя
    // In real app, this would send location to server
    if (_activeRide != null) {
      // Для демонстрации - немного сдвигаем позицию водителя
      setState(() {
        // Обновляем маркеры на карте
        _updateMapMarkers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {
          // Находим активную поездку клиента
          final authState = context.read<AuthBloc>().state;
          if (authState.isAuthenticated && authState.user != null) {
            final activeRide = state.rides.where((ride) =>
              ride.clientId == authState.user!.id &&
              MapboxService.isRideInProgress(ride)
            ).firstOrNull;
            
            if (activeRide != _activeRide) {
              setState(() {
                _activeRide = activeRide;
              });
              _updateMapMarkers();
              _startDriverLocationUpdates();
            }
          }
        },
        child: Stack(
          children: [
            // Map
            MapWidget(
              key: const ValueKey('client_map'),
              onMapCreated: _onMapCreated,
            ),
            
            // Информационная панель сверху
            SafeArea(
              child: _buildInfoPanel(),
            ),
            
            // Control buttons
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
                '${_activeRide!.from.address} → ${_activeRide!.to.address}',
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
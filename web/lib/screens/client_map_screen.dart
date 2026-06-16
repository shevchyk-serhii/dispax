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
import '../modules/core/models/websocket_event.dart';
import '../modules/core/services/websocket_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/date_utils.dart';
import '../modules/flight_management/muc_checkpoints.dart';

class ClientMapScreen extends StatefulWidget {
  const ClientMapScreen({super.key});

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _driverAnnotationManager;
  PointAnnotation? _driverAnnotation;
  PointAnnotationManager? _selfAnnotationManager;
  PointAnnotation? _selfAnnotation;
  Uint8List? _clientMarkerImage;
  CircleAnnotationManager? _circleAnnotationManager;

  StreamSubscription<geo.Position>? _locationSubscription;
  StreamSubscription? _wsSubscription;
  geo.Position? _currentPosition;
  Ride? _activeRide;

  final LocationService _locationService = LocationService.instance;
  bool _sharingLocation = false;
  RideService? _rideService;
  Uint8List? _driverMarkerImage;
  String? _approachingBannerMessage;
  Timer? _pulseTimer;
  bool _pulseState = false;
  final Set<String> _airportCheckpointSent = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _listenToWebSocket();
    _startPulse();
  }

  void _startPulse() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      _pulseState = !_pulseState;
      if (_driverAnnotation != null) {
        _driverAnnotation!.iconSize = _pulseState ? 2.4 : 1.8;
        _driverAnnotationManager?.update(_driverAnnotation!);
      }
      if (_selfAnnotation != null) {
        _selfAnnotation!.iconSize = _pulseState ? 1.8 : 1.3;
        _selfAnnotationManager?.update(_selfAnnotation!);
      }
    });
  }

  @override
  void didChangeDependencies() {
    _rideService ??= RideService(apiClient: context.read<AuthBloc>().apiClient);
    super.didChangeDependencies();
    if (_activeRide == null) {
      final authState = context.read<AuthBloc>().state;
      final rideState = context.read<RideBloc>().state;
      if (authState.user != null) {
        final activeRide = rideState.rides
            .where(
              (ride) =>
                  ride.clientId == authState.user!.id &&
                  (ride.status == RideStatus.assigned ||
                      ride.status == RideStatus.inProgress),
            )
            .firstOrNull;
        if (activeRide != null) {
          _activeRide = activeRide;
        }
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _wsSubscription?.cancel();
    _pulseTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  void _listenToWebSocket() {
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;

      if (event.isLocationUpdated &&
          event.locationType == 'driver' &&
          (_activeRide == null || event.driverId == _activeRide!.driverId) &&
          event.latitude != null &&
          event.longitude != null) {
        if (_activeRide != null) {
          setState(() {
            _activeRide = _activeRide!.copyWith(
              driverLocation: loc.Location(
                address: '',
                latitude: event.latitude,
                longitude: event.longitude,
              ),
            );
          });
        }
        _updateDriverMarker(event.latitude!, event.longitude!);
        _centerOnDriverAndClient(event.latitude!, event.longitude!);

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
      if (_mapboxMap != null) {
        _mapboxMap!.setCamera(
          MapboxService.createCameraOptions(
            latitude: position.latitude,
            longitude: position.longitude,
            zoom: 15.0,
          ),
        );
      }
    }

    final started = await _locationService.startLocationTracking();
    if (started) {
      _locationSubscription = _locationService.positionStream.listen((
        geo.Position position,
      ) {
        setState(() {
          _currentPosition = position;
        });
        if (_firstGpsFix) {
          _firstGpsFix = false;
          _mapboxMap?.setCamera(
            MapboxService.createCameraOptions(
              latitude: position.latitude,
              longitude: position.longitude,
              zoom: 15.0,
            ),
          );
        }
        _updateCurrentLocationMarker();

        // Share client location if toggle is on
        if (_sharingLocation && _activeRide != null) {
          _rideService?.updateClientLocation(
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

    _driverAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _selfAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

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

  Future<void> _updateCurrentLocationMarker() async {
    if (_mapboxMap == null || _currentPosition == null) return;

    final name = context.read<AuthBloc>().state.user?.name;

    if (_selfAnnotation != null) {
      await _selfAnnotationManager?.delete(_selfAnnotation!);
      _selfAnnotation = null;
    }

    _clientMarkerImage ??= (await rootBundle.load(
      'assets/client_marker.png',
    )).buffer.asUint8List();

    _selfAnnotation = await _selfAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
        image: _clientMarkerImage,
        iconSize: 1.5,
        textField: name,
        textSize: 13.0,
        textColor: 0xFF1B5E20,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2.0,
        textOffset: [0.0, -2.5],
      ),
    );
  }

  Future<void> _updateDriverMarker(double latitude, double longitude) async {
    if (_driverAnnotationManager == null) return;

    _driverMarkerImage ??= (await rootBundle.load(
      'assets/driver_marker.png',
    )).buffer.asUint8List();
    final Uint8List imageData = _driverMarkerImage!;

    if (_driverAnnotation != null) {
      await _driverAnnotationManager?.delete(_driverAnnotation!);
      _driverAnnotation = null;
    }
    _driverAnnotation = await _driverAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(longitude, latitude)),
        image: imageData,
        iconSize: 2.0,
        textField: _activeRide?.driverName,
        textSize: 13.0,
        textColor: 0xFF0D47A1,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2.0,
        textOffset: [0.0, 2.5],
      ),
    );
  }

  void _updateMapMarkers() {
    if (_mapboxMap == null || _circleAnnotationManager == null) return;

    _updateCurrentLocationMarker();

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
        _updateDriverMarker(
          _activeRide!.driverLocation!.latitude!,
          _activeRide!.driverLocation!.longitude!,
        );
      }

      final cameraOptions = MapboxService.getCameraForRoute(
        from: _activeRide!.from,
        to: _activeRide!.to,
        currentPosition: _currentPosition,
      );

      _mapboxMap?.setCamera(cameraOptions);
    }
  }

  void _centerOnDriverAndClient(double driverLat, double driverLng) {
    if (_mapboxMap == null) return;

    final List<double> lats = [driverLat];
    final List<double> lngs = [driverLng];

    if (_currentPosition != null) {
      lats.add(_currentPosition!.latitude);
      lngs.add(_currentPosition!.longitude);
    }

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom;
    if (maxDiff < 0.005) {
      zoom = 15.0;
    } else if (maxDiff < 0.02) {
      zoom = 13.5;
    } else if (maxDiff < 0.05) {
      zoom = 12.0;
    } else {
      zoom = 11.0;
    }

    _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
      ),
    );
  }

  bool _driverApproachingShown = false;
  bool _firstGpsFix = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {
          final authState = context.read<AuthBloc>().state;
          if (authState.isAuthenticated && authState.user != null) {
            final activeRide = state.rides
                .where(
                  (ride) =>
                      ride.clientId == authState.user!.id &&
                      (ride.status == RideStatus.assigned ||
                          ride.status == RideStatus.inProgress),
                )
                .firstOrNull;

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

            Positioned(bottom: 100, right: 16, child: _buildControlButtons()),
          ],
        ),
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
                Icons.location_on,
                color: AppColors.clientColor,
                size: AppDimensions.iconMedium,
              ),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Your Location',
                style: AppStyles.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),

          if (_activeRide != null) ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildActiveRideInfo(),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildLocationSharingToggle(),
            if (_activeRide!.isAirportTransfer &&
                _activeRide!.isArrival &&
                _activeRide!.status == RideStatus.inProgress) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              _buildAirportCheckpointPanel(),
            ],
          ] else ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'No active ride',
              style: AppStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
          color: _sharingLocation
              ? AppColors.success
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: AppDimensions.iconSmall,
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Expanded(
          child: Text(
            'Share my location',
            style: AppStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Switch(
          value: _sharingLocation,
          onChanged: (value) {
            setState(() => _sharingLocation = value);
            if (value && _currentPosition != null && _activeRide != null) {
              _rideService?.updateClientLocation(
                _activeRide!.id,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }
          },
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.success,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
            style: AppStyles.labelSmall.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.paddingMedium),

        Row(
          children: [
            Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: AppDimensions.iconSmall,
            ),
            const SizedBox(width: AppDimensions.paddingSmall),
            Text(
              'Pickup: ${AppDateUtils.formatDateTime(_activeRide!.pickupDateTime)}',
              style: AppStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.paddingSmall),

        Row(
          children: [
            Icon(
              Icons.route,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: AppDimensions.iconSmall,
            ),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(
              child: Text(
                '${_activeRide!.from.address} -> ${_activeRide!.to.address}',
                style: AppStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
              Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppDimensions.iconSmall,
              ),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Driver: ${_activeRide!.driverName}',
                style: AppStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  int _checkpointOrdinal(String? key) {
    const order = ['landed', 'arrivals_hall', 'terminal_exit'];
    if (key == null) return -1;
    return order.indexOf(key);
  }

  Widget _buildAirportCheckpointPanel() {
    if (_activeRide == null) return const SizedBox.shrink();

    final currentOrdinal = _checkpointOrdinal(_activeRide!.airportCheckpoint);

    const checkpoints = [
      ('landed', 'Landed'),
      ('arrivals_hall', 'Arrivals Hall'),
      ('terminal_exit', 'Terminal Exit'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My location in terminal',
          style: AppStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: checkpoints.map((entry) {
            final (key, label) = entry;
            final buttonOrdinal = _checkpointOrdinal(key);
            final isPassed = buttonOrdinal <= currentOrdinal;

            return isPassed
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 16,
                    ),
                    label: Text(label),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _airportCheckpointSent.contains(key)
                        ? null
                        : () async {
                            try {
                              await _rideService?.markAirportCheckpoint(
                                _activeRide!.id,
                                key,
                              );
                              setState(() {
                                _airportCheckpointSent.add(key);
                                _activeRide = _activeRide!.copyWith(
                                  airportCheckpoint: key,
                                );
                              });
                            } catch (_) {
                              // best-effort; silently ignore errors
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(label),
                  );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildApproachingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
      ),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.route,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
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
        return Theme.of(context).colorScheme.primary;
      case RideStatus.inProgress:
        return AppColors.clientColor;
      case RideStatus.completed:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

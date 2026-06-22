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
import '../utils/ride_status_styles.dart';

class ClientMapScreen extends StatefulWidget {
  const ClientMapScreen({super.key});

  /// Client-facing wording for the ride status shown on the map pill.
  ///
  /// Friendlier than the raw status label (e.g. "Driver on the way" instead of
  /// "Assigned").
  static String clientStatusLabel(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'Finding a driver';
      case RideStatus.assigned:
        return 'Driver on the way';
      case RideStatus.inProgress:
        return 'On trip';
      case RideStatus.completed:
        return 'Trip completed';
      case RideStatus.cancelled:
        return 'Trip cancelled';
    }
  }

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  MapboxMap? _mapboxMap;

  // Driver and client (self) are drawn as themed CircleAnnotations (design:
  // pulsing dots). Driver colour follows the ride status palette, client is the
  // corporate accent. Route pickup/dropoff stay on a separate circle manager so
  // the pulse animation never re-creates them.
  CircleAnnotationManager? _driverCircleManager;
  CircleAnnotation? _driverCircle;
  CircleAnnotationManager? _selfCircleManager;
  CircleAnnotation? _selfCircle;
  CircleAnnotationManager? _routeCircleManager;
  // Driver name label rides above the driver dot.
  PointAnnotationManager? _driverLabelManager;
  PointAnnotation? _driverLabel;

  StreamSubscription<geo.Position>? _locationSubscription;
  StreamSubscription? _wsSubscription;
  geo.Position? _currentPosition;
  Ride? _activeRide;

  final LocationService _locationService = LocationService.instance;
  bool _sharingLocation = false;
  RideService? _rideService;
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
      if (_driverCircle != null) {
        _driverCircle!.circleRadius = _pulseState ? 15.0 : 12.0;
        _driverCircleManager?.update(_driverCircle!);
      }
      if (_selfCircle != null) {
        _selfCircle!.circleRadius = _pulseState ? 12.0 : 9.0;
        _selfCircleManager?.update(_selfCircle!);
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

    // Route pickup/dropoff dots are created first so the live driver/client
    // markers render on top of them.
    _routeCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _selfCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _driverCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _driverLabelManager = await mapboxMap.annotations
        .createPointAnnotationManager();

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

    // Pulsing cyan dot (design §8) — recreate so it tracks the latest GPS fix.
    if (_selfCircle != null) {
      await _selfCircleManager?.delete(_selfCircle!);
      _selfCircle = null;
    }

    _selfCircle = await _selfCircleManager?.create(
      MapboxService.createClientMarker(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: _pulseState ? 12.0 : 9.0,
      ),
    );
  }

  Future<void> _updateDriverMarker(double latitude, double longitude) async {
    if (_driverCircleManager == null) return;

    // Driver dot colour follows the ride status palette (design §8); falls back
    // to the assigned colour when no active ride status is known yet.
    final status = _activeRide?.status ?? RideStatus.assigned;
    final color = RideStatusStyles.getStatusColorValue(status);

    if (_driverCircle != null) {
      await _driverCircleManager?.delete(_driverCircle!);
      _driverCircle = null;
    }
    _driverCircle = await _driverCircleManager?.create(
      MapboxService.createDriverMarker(
        latitude: latitude,
        longitude: longitude,
        color: color,
        radius: _pulseState ? 15.0 : 12.0,
        driverId: _activeRide?.driverId,
      ),
    );

    // Driver name label above the dot.
    final name = _activeRide?.driverName;
    if (_driverLabel != null) {
      await _driverLabelManager?.delete(_driverLabel!);
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

  void _updateMapMarkers() {
    if (_mapboxMap == null || _routeCircleManager == null) return;

    _updateCurrentLocationMarker();

    if (_activeRide != null) {
      // Clear stale pickup/dropoff dots before redrawing.
      _routeCircleManager?.deleteAll();

      final rideMarkers = MapboxService.createRideMarkers(
        from: _activeRide!.from,
        to: _activeRide!.to,
      );

      for (final marker in rideMarkers) {
        _routeCircleManager?.create(marker);
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
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
              // ── Full-bleed map ──────────────────────────────────────────────
              MapWidget(
                key: const ValueKey('client_map'),
                // Pin the style explicitly: relying on the SDK default left the
                // map black whenever the style failed to resolve. Streets-v12
                // is the classic colour street map used by most ride apps.
                styleUri: MapboxStyles.MAPBOX_STREETS,
                onMapCreated: _onMapCreated,
              ),

              // ── Top overlay: back btn + status pill ─────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Back button — theme-aware so it stays legible in dark.
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
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
                      ),

                      const SizedBox(width: 12),

                      // Status pill — colour and label follow the ride status.
                      if (_activeRide != null) _buildStatusPill(_activeRide!),
                    ],
                  ),
                ),
              ),

              // ── Approaching banner (if any) ─────────────────────────────────
              if (_approachingBannerMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 68,
                  left: 16,
                  right: 16,
                  child: _buildApproachingBanner(),
                ),

              // ── FAB controls ────────────────────────────────────────────────
              Positioned(
                bottom: _activeRide != null ? 270 : 100,
                right: 16,
                child: _buildControlButtons(),
              ),

              // ── Driver bottom sheet ─────────────────────────────────────────
              if (_activeRide != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildDriverBottomSheet(),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildNoActiveRidePanel(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Status pill ──────────────────────────────────────────────────────────────

  Widget _buildStatusPill(Ride ride) {
    final brightness = Theme.of(context).brightness;
    final status = ride.status;
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
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            ClientMapScreen.clientStatusLabel(status),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Driver bottom sheet ──────────────────────────────────────────────────────

  /// "4.9 · 1.2k rides" when the driver has an average rating, otherwise a
  /// neutral placeholder. Counts ≥ 1000 are abbreviated (1.2k).
  String _driverRatingLabel(Ride ride) {
    final rating = ride.driverRating;
    if (rating == null) return 'New driver';
    final count = ride.driverRatingCount ?? 0;
    final countLabel = count >= 1000
        ? '${(count / 1000).toStringAsFixed(1)}k rides'
        : '$count rides';
    return '${rating.toStringAsFixed(1)} · $countLabel';
  }

  Widget _buildDriverBottomSheet() {
    final ride = _activeRide!;
    final cs = Theme.of(context).colorScheme;

    // Driver initials
    final driverName = ride.driverName ?? 'Driver';
    final initials = driverName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join('');

    // ETA
    final eta = ride.etaMinutes;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Driver row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Name + rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 13,
                            color: Color(0xFFF59E0B), // amber
                          ),
                          const SizedBox(width: 3),
                          Text(
                            // Driver's average rating + how many ratings it is
                            // based on, from the RideDto. Degrade gracefully.
                            _driverRatingLabel(ride),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ETA
                if (eta != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$eta',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                            const TextSpan(
                              text: ' min',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'to pickup',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Vehicle chip
            _buildVehicleChip(cs),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                // Call button (accent — the one live action per screen, HANDOFF §5)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: launch tel: URL when driver phone is available
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 13.5,
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
                        elevation: 0,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Message button (outlined)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: open chat screen with driver
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text(
                        'Message',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: const BorderSide(color: Color(0xFFD4D4D8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Airport checkpoint panel (if applicable)
            if (_activeRide!.isAirportTransfer &&
                _activeRide!.isArrival &&
                _activeRide!.status == RideStatus.inProgress) ...[
              const SizedBox(height: 12),
              _buildAirportCheckpointPanel(),
            ],

            // Location sharing toggle
            const SizedBox(height: 8),
            _buildLocationSharingToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleChip(ColorScheme cs) {
    // Vehicle fields (plate, model, color) are not on Ride model yet.
    // Degrade gracefully: show what we have.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // No vehicle model on Ride yet
                  'Vehicle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                // Plate not on model — omit gracefully
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── No active ride panel ─────────────────────────────────────────────────────

  Widget _buildNoActiveRidePanel() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D4D8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No active ride',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your driver will appear here once a ride is assigned.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Approaching banner ───────────────────────────────────────────────────────

  Widget _buildApproachingBanner() {
    return Container(
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

  // ─── Location sharing toggle ──────────────────────────────────────────────────

  Widget _buildLocationSharingToggle() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          _sharingLocation ? Icons.location_on : Icons.location_off,
          color: _sharingLocation ? AppColors.success : cs.onSurfaceVariant,
          size: AppDimensions.iconSmall,
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Expanded(
          child: Text(
            'Share my location',
            style: AppStyles.bodySmall.copyWith(color: cs.onSurface),
          ),
        ),
        Switch.adaptive(
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
          activeTrackColor: AppColors.accent,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: cs.onSurfaceVariant,
        ),
      ],
    );
  }

  // ─── Airport checkpoint panel ─────────────────────────────────────────────────

  int _checkpointOrdinal(String? key) {
    const order = ['landed', 'arrivals_hall', 'terminal_exit'];
    if (key == null) return -1;
    return order.indexOf(key);
  }

  Widget _buildAirportCheckpointPanel() {
    if (_activeRide == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
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
            color: cs.onSurfaceVariant,
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

  // ─── FAB controls ─────────────────────────────────────────────────────────────

  Widget _buildControlButtons() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'center_location',
          onPressed: _centerOnCurrentLocation,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.my_location),
        ),

        if (_activeRide != null) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          FloatingActionButton(
            heroTag: 'center_route',
            onPressed: _centerOnRoute,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            child: const Icon(Icons.route),
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
}

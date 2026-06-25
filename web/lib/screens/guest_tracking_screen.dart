import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../modules/core/services/api_client.dart';
import '../modules/core/services/mapbox_service.dart';
import '../modules/core/models/websocket_event.dart';
import '../modules/ride_management/models/public_ride.dart';
import '../modules/ride_management/services/guest_track_service.dart';

/// Public, auth-free ride tracking page opened from a share link (`/track/<token>`). Shows the live driver position,
/// status, ETA and route — with NO driver identity (name/phone/rating) and NO price. A trimmed sibling of
/// ClientMapScreen that reads from the public `/track` API instead of RideBloc/AuthBloc.
class GuestTrackingScreen extends StatefulWidget {
  final String token;

  /// Injected for tests; production builds use the defaults (tokenless ApiClient + the real guest socket).
  final GuestTrackService? trackService;
  final Stream<WebSocketEvent>? eventStreamOverride;

  const GuestTrackingScreen({
    super.key,
    required this.token,
    this.trackService,
    this.eventStreamOverride,
  });

  /// Friendly, status-aware label for the guest. Pure + static so it is unit-testable without the widget. `status` is
  /// the raw backend enum string (e.g. "InProgress").
  @visibleForTesting
  static String guestStatusLabel(
    AppLocalizations l10n,
    String status, {
    required bool driverAssigned,
  }) {
    switch (status) {
      case 'Requested':
        return l10n.guestFindingDriver;
      case 'Assigned':
      case 'Confirmed':
        return l10n.guestDriverOnTheWay;
      case 'InProgress':
        return l10n.guestOnTrip;
      case 'Completed':
        return l10n.guestTripCompleted;
      case 'Cancelled':
        return l10n.guestTripCancelled;
      case 'HandedOff':
        return l10n.guestDriverOnTheWay;
      default:
        return driverAssigned
            ? l10n.guestDriverOnTheWay
            : l10n.guestFindingDriver;
    }
  }

  /// Whether an incoming location event should move the guest's driver marker: only driver-type location updates.
  /// Pure + static for unit testing without Mapbox.
  @visibleForTesting
  static bool shouldApplyGuestDriverLocation(WebSocketEvent event) =>
      event.isLocationUpdated &&
      event.locationType == 'driver' &&
      event.latitude != null &&
      event.longitude != null;

  @override
  State<GuestTrackingScreen> createState() => _GuestTrackingScreenState();
}

class _GuestTrackingScreenState extends State<GuestTrackingScreen> {
  late final GuestTrackService _trackService;
  GuestWebSocketClient? _wsClient;
  StreamSubscription<WebSocketEvent>? _wsSub;

  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _driverCircleManager;
  CircleAnnotationManager? _routeCircleManager;
  CircleAnnotation? _driverCircle;

  PublicRide? _ride;
  bool _loading = true;
  bool _expired = false;
  String? _approachingBanner;

  @override
  void initState() {
    super.initState();
    _trackService = widget.trackService ?? GuestTrackService();
    _loadRide();
    _listenToEvents();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _trackService.fetchPublicRide(widget.token);
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _loading = false;
      });
      _updateMapMarkers();
    } on GuestLinkExpiredException {
      if (!mounted) return;
      setState(() {
        _expired = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _expired = true;
        _loading = false;
      });
    }
  }

  void _listenToEvents() {
    final stream = widget.eventStreamOverride ?? _connectGuestSocket();
    _wsSub = stream.listen(_onEvent);
  }

  Stream<WebSocketEvent> _connectGuestSocket() {
    final client = GuestWebSocketClient(
      wsBaseUrl: ApiClient.wsBaseUrl,
      token: widget.token,
    );
    _wsClient = client;
    client.connect();
    return client.eventStream;
  }

  void _onEvent(WebSocketEvent event) {
    if (!mounted || _ride == null) return;
    if (GuestTrackingScreen.shouldApplyGuestDriverLocation(event)) {
      setState(() {
        _ride = _ride!.copyWith(
          driverLatitude: event.latitude,
          driverLongitude: event.longitude,
        );
      });
      _updateDriverMarker(event.latitude!, event.longitude!);
    } else if (event.isRideStatusChanged && event.newStatus != null) {
      setState(() => _ride = _ride!.copyWith(status: event.newStatus));
    } else if (event.isDriverApproaching) {
      setState(
        () => _approachingBanner = AppLocalizations.of(
          context,
        )!.guestDriverApproaching,
      );
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _routeCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _driverCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _updateMapMarkers();
  }

  Future<void> _updateMapMarkers() async {
    final ride = _ride;
    if (_mapboxMap == null || ride == null) return;

    // Route markers (pickup green / dropoff red).
    if (_routeCircleManager != null) {
      await _routeCircleManager!.deleteAll();
      final markers = MapboxService.createRideMarkers(
        from: ride.pickup,
        to: ride.dropoff,
      );
      for (final m in markers) {
        await _routeCircleManager!.create(m);
      }
    }

    // Camera to fit the route.
    await _mapboxMap!.setCamera(
      MapboxService.getCameraForRoute(from: ride.pickup, to: ride.dropoff),
    );

    if (ride.hasDriverLocation) {
      await _updateDriverMarker(ride.driverLatitude!, ride.driverLongitude!);
    }
  }

  Future<void> _updateDriverMarker(double lat, double lng) async {
    if (_driverCircleManager == null) return;
    if (_driverCircle != null) {
      await _driverCircleManager?.delete(_driverCircle!);
    }
    _driverCircle = await _driverCircleManager?.create(
      MapboxService.createDriverMarker(
        latitude: lat,
        longitude: lng,
        color: 0xFF2196F3,
      ),
    );
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsClient?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_expired || _ride == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_off,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.guestLinkExpired,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ride = _ride!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guestTrackingTitle)),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('guest_map'),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
          ),
          if (_approachingBanner != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _approachingBanner!,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildInfoCard(l10n, ride),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n, PublicRide ride) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    GuestTrackingScreen.guestStatusLabel(
                      l10n,
                      ride.status,
                      driverAssigned: ride.driverAssigned,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (ride.etaMinutes != null)
                  Text(
                    l10n.guestEtaMinutes(ride.etaMinutes!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _addressRow(
              Icons.trip_origin,
              l10n.guestPickup,
              ride.pickup.address,
              theme,
            ),
            const SizedBox(height: 8),
            _addressRow(
              Icons.place,
              l10n.guestDropoff,
              ride.dropoff.address,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(
    IconData icon,
    String label,
    String address,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(address, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../core/services/mapbox_service.dart';
import '../../core/models/location.dart';

class RideMapWidget extends StatefulWidget {
  final Location? fromLocation;
  final Location? toLocation;
  final double height;
  final bool showRoute;
  final VoidCallback? onMapReady;

  const RideMapWidget({
    super.key,
    this.fromLocation,
    this.toLocation,
    this.height = 300.0,
    this.showRoute = true,
    this.onMapReady,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MapWidget(
          key: ValueKey(
            'map_${widget.fromLocation?.address}_${widget.toLocation?.address}',
          ),
          cameraOptions: _createInitialCamera(),
          onMapCreated: _onMapCreated,
        ),
      ),
    );
  }

  CameraOptions _createInitialCamera() {
    double lat = MapboxService.defaultLatitude;
    double lng = MapboxService.defaultLongitude;
    double zoom = 12.0;

    if (widget.fromLocation != null) {

      _updateCameraToLocations();
    }

    return MapboxService.createCameraOptions(
      latitude: lat,
      longitude: lng,
      zoom: zoom,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    await _addLocationMarkers();
    if (widget.showRoute) {
      await _addRoute();
    }

    widget.onMapReady?.call();
  }

  Future<void> _updateCameraToLocations() async {
    if (widget.fromLocation == null && widget.toLocation == null) return;

    List<double>? fromCoords;
    List<double>? toCoords;

    if (widget.fromLocation != null) {
      fromCoords = await MapboxService.geocodeAddress(
        widget.fromLocation!.address,
      );
    }

    if (widget.toLocation != null) {
      toCoords = await MapboxService.geocodeAddress(widget.toLocation!.address);
    }

    if (fromCoords != null && toCoords != null) {

      double centerLat = (fromCoords[0] + toCoords[0]) / 2;
      double centerLng = (fromCoords[1] + toCoords[1]) / 2;

      final camera = MapboxService.createCameraOptions(
        latitude: centerLat,
        longitude: centerLng,
        zoom: 12.0,
      );

      await _mapboxMap?.setCamera(camera);
    } else if (fromCoords != null) {
      final camera = MapboxService.createCameraOptions(
        latitude: fromCoords[0],
        longitude: fromCoords[1],
        zoom: 14.0,
      );
      await _mapboxMap?.setCamera(camera);
    } else if (toCoords != null) {
      final camera = MapboxService.createCameraOptions(
        latitude: toCoords[0],
        longitude: toCoords[1],
        zoom: 14.0,
      );
      await _mapboxMap?.setCamera(camera);
    }
  }

  Future<void> _addLocationMarkers() async {
    if (_circleAnnotationManager == null) return;

    List<CircleAnnotationOptions> annotations = [];

    if (widget.fromLocation != null) {
      final coords = await MapboxService.geocodeAddress(
        widget.fromLocation!.address,
      );
      if (coords != null) {
        annotations.add(
          MapboxService.createLocationMarker(
            latitude: coords[0],
            longitude: coords[1],
            color: 'green',
          ),
        );
      }
    }

    if (widget.toLocation != null) {
      final coords = await MapboxService.geocodeAddress(
        widget.toLocation!.address,
      );
      if (coords != null) {
        annotations.add(
          MapboxService.createLocationMarker(
            latitude: coords[0],
            longitude: coords[1],
            color: 'red',
          ),
        );
      }
    }

    if (annotations.isNotEmpty) {
      await _circleAnnotationManager!.createMulti(annotations);
    }
  }

  Future<void> _addRoute() async {
    if (_polylineAnnotationManager == null ||
        widget.fromLocation == null ||
        widget.toLocation == null) {
      return;
    }

    final fromCoords = await MapboxService.geocodeAddress(
      widget.fromLocation!.address,
    );
    final toCoords = await MapboxService.geocodeAddress(
      widget.toLocation!.address,
    );

    if (fromCoords != null && toCoords != null) {
      final routePoints = await MapboxService.getRoutePoints(
        fromCoords[0],
        fromCoords[1],
        toCoords[0],
        toCoords[1],
      );

      final polylineAnnotation = PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePoints),
        lineColor: 0xFF2196F3,
        lineWidth: 4.0,
      );

      await _polylineAnnotationManager!.create(polylineAnnotation);
    }
  }

  @override
  void dispose() {
    _circleAnnotationManager?.deleteAll();
    _polylineAnnotationManager?.deleteAll();
    super.dispose();
  }
}

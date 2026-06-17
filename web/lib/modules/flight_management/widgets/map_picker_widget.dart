import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// An OpenStreetMap-backed coordinate picker widget.
///
/// Displays a tile map with a draggable marker. Accepts an initial position and
/// invokes [onLocationPicked] whenever the user taps or drags the marker to a
/// new location. Two-way bound to companion lat/lon [TextEditingController]s so
/// text field edits also move the marker.
///
/// Uses the public OSM tile URL (no API key required). Tile attribution to
/// OpenStreetMap contributors is displayed as required by the tile license.
class MapPickerWidget extends StatefulWidget {
  const MapPickerWidget({
    super.key,
    this.initialLat,
    this.initialLon,
    required this.latController,
    required this.lonController,
    required this.onLocationPicked,
  });

  final double? initialLat;
  final double? initialLon;

  /// Text controllers that stay in sync with the picked coordinates.
  final TextEditingController latController;
  final TextEditingController lonController;

  /// Called whenever the user picks a new location (tap or drag).
  final void Function(double lat, double lon) onLocationPicked;

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  // Default to Munich airport area when no initial position is provided.
  static const double _defaultLat = 48.3537;
  static const double _defaultLon = 11.7860;

  late LatLng _markerPos;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _markerPos = LatLng(
      widget.initialLat ?? _defaultLat,
      widget.initialLon ?? _defaultLon,
    );

    // Keep text fields in sync with initial marker position.
    widget.latController.text = _markerPos.latitude.toStringAsFixed(6);
    widget.lonController.text = _markerPos.longitude.toStringAsFixed(6);

    // Listen to text field changes and move the marker accordingly.
    widget.latController.addListener(_onLatTextChanged);
    widget.lonController.addListener(_onLonTextChanged);
  }

  @override
  void dispose() {
    widget.latController.removeListener(_onLatTextChanged);
    widget.lonController.removeListener(_onLonTextChanged);
    super.dispose();
  }

  void _onLatTextChanged() {
    final lat = double.tryParse(widget.latController.text);
    if (lat != null && lat >= -90 && lat <= 90) {
      final newPos = LatLng(lat, _markerPos.longitude);
      setState(() => _markerPos = newPos);
      _mapController.move(newPos, _mapController.camera.zoom);
    }
  }

  void _onLonTextChanged() {
    final lon = double.tryParse(widget.lonController.text);
    if (lon != null && lon >= -180 && lon <= 180) {
      final newPos = LatLng(_markerPos.latitude, lon);
      setState(() => _markerPos = newPos);
      _mapController.move(newPos, _mapController.camera.zoom);
    }
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() => _markerPos = point);
    widget.latController.text = point.latitude.toStringAsFixed(6);
    widget.lonController.text = point.longitude.toStringAsFixed(6);
    widget.onLocationPicked(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _markerPos,
            initialZoom: 14.0,
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.dispax.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _markerPos,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
            // OSM attribution required by tile license.
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

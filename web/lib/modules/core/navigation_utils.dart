import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/location.dart';
import 'models/person.dart';
import '../ride_management/models/ride.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';

class NavigationUtils {
  static Future<void> openGoogleMapsNavigation(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$destinationAddress&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      await _tryGoogleMapsApp(destination);
    }
  }

  static Future<void> openGoogleMapsRoute(
    Location origin,
    Location destination,
  ) async {
    final originParam = origin.latitude != null && origin.longitude != null
        ? '${origin.latitude},${origin.longitude}'
        : Uri.encodeComponent(origin.address);
    final destinationParam =
        destination.latitude != null && destination.longitude != null
        ? '${destination.latitude},${destination.longitude}'
        : Uri.encodeComponent(destination.address);

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$destinationParam&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      await _tryGoogleMapsAppWithRoute(origin, destination);
    }
  }

  static Future<void> _tryGoogleMapsApp(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final appUrl =
        'comgooglemaps://?daddr=$destinationAddress&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> _tryGoogleMapsAppWithRoute(
    Location origin,
    Location destination,
  ) async {
    final originParam = origin.latitude != null && origin.longitude != null
        ? '${origin.latitude},${origin.longitude}'
        : Uri.encodeComponent(origin.address);
    final destinationParam =
        destination.latitude != null && destination.longitude != null
        ? '${destination.latitude},${destination.longitude}'
        : Uri.encodeComponent(destination.address);

    final appUrl =
        'comgooglemaps://?saddr=$originParam&daddr=$destinationParam&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> openGoogleMapsLocation(Location location) async {
    final address = Uri.encodeComponent(location.address);

    String googleMapsUrl;
    if (location.latitude != null && location.longitude != null) {
      googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    } else {
      googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$address';
    }

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      throw 'Could not open location: $e';
    }
  }

  static Future<Ride?> navigateToEditRide(
    BuildContext context,
    Ride ride,
  ) async {
    return showAdaptiveDialog<Ride>(
      context: context,
      builder: (ctx) => _EditRideDialog(ride: ride),
    );
  }

  static Future<Person?> navigateToDriverSelection(BuildContext context) async {
    // Driver selection is now handled by the dispatcher dashboard's
    // tap-to-assign flow (pending_rides_panel.dart _showDriverSelectionSheet)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use the Dispatcher Dashboard to assign drivers'),
      ),
    );
    return null;
  }

  static Future<void> navigateToMap(BuildContext context, Ride ride) async {
    await openGoogleMapsRoute(ride.from, ride.to);
  }
}

class _EditRideDialog extends StatefulWidget {
  final Ride ride;
  const _EditRideDialog({required this.ride});

  @override
  State<_EditRideDialog> createState() => _EditRideDialogState();
}

class _EditRideDialogState extends State<_EditRideDialog> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _flightCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.ride.from.address);
    _toCtrl = TextEditingController(text: widget.ride.to.address);
    _dateCtrl = TextEditingController(
      text: DateFormat("yyyy-MM-dd'T'HH:mm").format(widget.ride.pickupDateTime),
    );
    _notesCtrl = TextEditingController(text: widget.ride.notes ?? '');
    _flightCtrl = TextEditingController(text: widget.ride.flightNumber ?? '');
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    _flightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final apiClient = context.read<AuthBloc>().apiClient;
    // Parse local time and convert to UTC ISO-8601 for the backend
    DateTime localDt;
    try {
      localDt = DateFormat(
        "yyyy-MM-dd'T'HH:mm",
      ).parseStrict(_dateCtrl.text.trim());
    } catch (_) {
      setState(() {
        _error = 'Invalid date format. Use: yyyy-MM-ddTHH:mm';
        _saving = false;
      });
      return;
    }
    final utcIso = localDt.toUtc().toIso8601String();

    final body = <String, dynamic>{
      'from': {'address': _fromCtrl.text.trim()},
      'to': {'address': _toCtrl.text.trim()},
      'pickupDateTime': utcIso,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (_flightCtrl.text.trim().isNotEmpty)
        'flightNumber': _flightCtrl.text.trim(),
    };

    try {
      final response = await apiClient.put('/rides/${widget.ride.id}', body);
      if (response.statusCode == 200) {
        final updated = Ride.fromJson(jsonDecode(response.body));
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _saving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Ride'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fromCtrl,
                decoration: const InputDecoration(
                  labelText: 'From',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toCtrl,
                decoration: const InputDecoration(
                  labelText: 'To',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pickup date/time (yyyy-MM-ddTHH:mm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Flight number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

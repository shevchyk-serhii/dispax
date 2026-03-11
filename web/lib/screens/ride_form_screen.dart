import 'package:flutter/material.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/models/create_ride_request.dart';
import '../modules/core/models/location.dart';
import '../modules/ride_management/services/mock_ride_service.dart';
import '../modules/ride_management/widgets/location_field.dart';
import '../modules/ride_management/widgets/date_time_picker.dart';

class RideFormScreen extends StatefulWidget {
  final Ride? ride;

  const RideFormScreen({super.key, this.ride});

  @override
  State<RideFormScreen> createState() => _RideFormScreenState();
}

class _RideFormScreenState extends State<RideFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final MockRideService _rideService = MockRideService();

  late TextEditingController _fromAddressController;
  late TextEditingController _toAddressController;

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final ride = widget.ride;
    _fromAddressController = TextEditingController(
      text: ride?.from.address ?? '',
    );
    _toAddressController = TextEditingController(text: ride?.to.address ?? '');

    _selectedDateTime =
        ride?.pickupDateTime ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _rideService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ride == null ? 'New Ride' : 'Edit Ride',
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LocationField(
                        controller: _fromAddressController,
                        hint: 'Pickup address',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'To',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LocationField(
                        controller: _toAddressController,
                        hint: 'Destination address',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Ride Time',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DateTimePicker(
                        selectedDateTime: _selectedDateTime,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _selectedDateTime = dateTime;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Route on Map',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('Map functionality temporarily disabled'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRide,
                  child: Text(
                    widget.ride == null
                        ? 'Create Ride'
                        : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRide() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select ride time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final from = Location(address: _fromAddressController.text);

      final to = Location(address: _toAddressController.text);

      if (widget.ride == null) {
        final request = CreateRideRequest(
          clientId: '',
          creatorId: '',
          companyId: '',
          pickupDateTime: _selectedDateTime!,
          from: from,
          to: to,
          clientName: 'Unknown Client',
        );
        await _rideService.createRide(request);
      } else {
        final ride = Ride(
          id: widget.ride!.id,
          clientId: widget.ride!.clientId,
          creatorId: widget.ride!.creatorId,
          driverId: widget.ride!.driverId,
          companyId: widget.ride!.companyId,
          scheduleDayId: widget.ride!.scheduleDayId,
          pickupDateTime: _selectedDateTime!,
          from: from,
          to: to,
          status: widget.ride!.status,
          clientName: widget.ride!.clientName,
        );
        await _rideService.updateRide(widget.ride!.id, ride);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

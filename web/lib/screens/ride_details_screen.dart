import 'package:flutter/material.dart';
import '../modules/core/models/person.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../modules/core/widgets/widgets.dart';
import '../modules/ride_management/services/ride_service.dart';
import '../modules/core/navigation_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;
  final bool isClientView;

  const RideDetailsScreen({
    Key? key,
    required this.ride,
    this.isClientView = false,
  }) : super(key: key);

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late Ride _currentRide;
  final RideService _rideService = RideService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isClientView ? 'My Ride #${_currentRide.id}' : 'Ride #${_currentRide.id}',
        backgroundColor: widget.isClientView ? Colors.green[600] : Colors.blue[600],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  RideStatusCard(
                    ride: _currentRide,
                    isClientView: widget.isClientView,
                  ),
                  const SizedBox(height: 16),

                  RideRouteCard(ride: _currentRide),
                  const SizedBox(height: 16),

                  if (_currentRide.isAirportTransfer) ...[
                    RideFlightCard(ride: _currentRide),
                    const SizedBox(height: 16),
                  ],

                  if (widget.isClientView && _currentRide.driver != null)
                    RidePersonCard(
                      person: _currentRide.driver!,
                      isDriver: true,
                      onCall: () => _makePhoneCall(_currentRide.driver!.phone),
                      onMessage: () => _sendMessage(_currentRide.driver!.phone),
                    )
                  else if (!widget.isClientView)
                    RidePersonCard(
                      person: _currentRide.client,
                      isDriver: false,
                      onCall: () => _makePhoneCall(_currentRide.client.phone),
                      onMessage: () => _sendMessage(_currentRide.client.phone),
                    ),
                  const SizedBox(height: 16),

                  RideActionsCard(
                    ride: _currentRide,
                    isClientView: widget.isClientView,
                    onEditRide: _canEditRide() ? () => _editRide(context) : null,
                    onCancelRide: _canCancelRide() ? () => _cancelRide(context) : null,
                    onStartRide: _canStartRide() ? () => _startRide(context) : null,
                    onCompleteRide: _canCompleteRide() ? () => _completeRide(context) : null,
                    onAssignDriver: _canAssignDriver() ? () => _assignDriver(context) : null,
                    onViewOnMap: () => _viewOnMap(context),
                    onShareRide: () => _shareRide(context),
                  ),
                ],
              ),
            ),
    );
  }

  bool _canEditRide() {
    return _currentRide.status == RideStatus.requested;
  }

  bool _canCancelRide() {
    return _currentRide.status != RideStatus.completed;
  }

  bool _canStartRide() {
    return !widget.isClientView && _currentRide.status == RideStatus.assigned;
  }

  bool _canCompleteRide() {
    return !widget.isClientView && _currentRide.status == RideStatus.inProgress;
  }

  bool _canAssignDriver() {
    return !widget.isClientView && _currentRide.status == RideStatus.requested;
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber?.isEmpty != false) return;

    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendMessage(String? phoneNumber) async {
    if (phoneNumber?.isEmpty != false) return;

    final uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _editRide(BuildContext context) async {
    final result = await NavigationUtils.navigateToEditRide(context, _currentRide);
    if (result != null) {
      setState(() {
        _currentRide = result;
      });
    }
  }

  Future<void> _cancelRide(BuildContext context) async {
    final confirmed = await _showConfirmationDialog(
      context,
      'Cancel Ride',
      'Are you sure you want to cancel this ride?',
    );

    if (confirmed) {
      await _updateRideStatus(RideStatus.cancelled);
    }
  }

  Future<void> _startRide(BuildContext context) async {
    await _updateRideStatus(RideStatus.inProgress);
  }

  Future<void> _completeRide(BuildContext context) async {
    final confirmed = await _showConfirmationDialog(
      context,
      'Complete Ride',
      'Mark this ride as completed?',
    );

    if (confirmed) {
      await _updateRideStatus(RideStatus.completed);
    }
  }

  Future<void> _assignDriver(BuildContext context) async {
    final driver = await NavigationUtils.navigateToDriverSelection(context);
    if (driver != null) {
      await _updateRideWithDriver(driver);
    }
  }

  Future<void> _viewOnMap(BuildContext context) async {
    NavigationUtils.navigateToMap(context, _currentRide);
  }

  Future<void> _shareRide(BuildContext context) async {

    final rideDetails = '''
Ride Details:
From: ${_currentRide.pickupLocation}
To: ${_currentRide.dropoffLocation}
Time: ${_currentRide.pickupTime}
Status: ${_currentRide.status.name}
''';

    Navigator.of(context).pop(rideDetails);
  }

  Future<void> _updateRideStatus(RideStatus newStatus) async {
    setState(() => _isLoading = true);

    try {
      final success = await _rideService.updateRideStatus(_currentRide.id, newStatus);
      if (success) {
        setState(() {
          _currentRide = _currentRide.copyWith(status: newStatus);
        });
      }

      _showSuccessMessage('Ride status updated successfully');
    } catch (e) {
      _showErrorMessage('Failed to update ride status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRideWithDriver(Person driver) async {
    setState(() => _isLoading = true);

    try {
      final updatedRide = await _rideService.assignDriver(_currentRide.id, driver.id);
      setState(() {
        _currentRide = updatedRide;
      });

      _showSuccessMessage('Driver assigned successfully');
    } catch (e) {
      _showErrorMessage('Failed to assign driver: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
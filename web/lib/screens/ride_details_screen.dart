import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../modules/core/models/person.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../modules/core/widgets/widgets.dart';
import '../modules/ride_management/services/ride_service.dart';
import '../modules/core/navigation_utils.dart';
import '../widgets/common/cancel_ride_dialog.dart';
import '../widgets/common/rate_ride_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';

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
  late RideService _rideService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideService = RideService(apiClient: context.read<AuthBloc>().apiClient);
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
                  const SizedBox(height: 8),

                  // Confirmation indicator
                  if (_currentRide.confirmationSent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Confirmation sent',
                            style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                  // Payment status indicator
                  if (_currentRide.paymentStatus != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentRide.paymentStatus == 'Paid'
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentRide.paymentStatus == 'Paid'
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentRide.paymentStatus == 'Paid' ? Icons.payment : Icons.pending,
                            size: 18,
                            color: _currentRide.paymentStatus == 'Paid'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_currentRide.paymentStatus}${_currentRide.paymentMethod != null ? ' (${_currentRide.paymentMethod})' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _currentRide.paymentStatus == 'Paid'
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Cancellation info
                  if (_currentRide.status == RideStatus.cancelled &&
                      _currentRide.cancellationReason != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cancellation Details',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                          const SizedBox(height: 4),
                          Text('Reason: ${_currentRide.cancellationReason}',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900)),
                          if (_currentRide.cancelledBy != null)
                            Text('Cancelled by: ${_currentRide.cancelledBy}',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                          if (_currentRide.cancellationFee != null && _currentRide.cancellationFee! > 0)
                            Text('Fee: \u20AC${_currentRide.cancellationFee!.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        ],
                      ),
                    ),
                  ],

                  // Rating info
                  if (_currentRide.rating != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(5, (i) => Icon(
                              i < _currentRide.rating! ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            )),
                          ),
                          if (_currentRide.ratingComment != null && _currentRide.ratingComment!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_currentRide.ratingComment!, style: TextStyle(fontSize: 13, color: Colors.amber.shade900)),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Rate ride button for clients on completed unrated rides
                  if (widget.isClientView &&
                      _currentRide.status == RideStatus.completed &&
                      _currentRide.rating == null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _rateRide(context),
                        icon: const Icon(Icons.star),
                        label: const Text('Rate This Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  // Notes and special requirements
                  if (_currentRide.notes != null && _currentRide.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          const SizedBox(height: 4),
                          Text(_currentRide.notes!, style: TextStyle(fontSize: 13, color: Colors.blue.shade900)),
                        ],
                      ),
                    ),
                  ],
                  if (_currentRide.specialRequirements != null && _currentRide.specialRequirements!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(_currentRide.specialRequirements!, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.purple.shade50,
                      side: BorderSide(color: Colors.purple.shade200),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],

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

                  if (_currentRide.status == RideStatus.assigned ||
                      _currentRide.status == RideStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(ride: _currentRide),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Open Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),

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
    final authState = context.read<AuthBloc>().state;
    final isDispatcher = authState.user?.role == PersonRole.dispatcher;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => CancelRideDialog(isDispatcher: isDispatcher),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final apiClient = context.read<AuthBloc>().apiClient;
        final body = <String, dynamic>{
          'status': 'Cancelled',
          'cancellationReason': result['reason'],
        };
        if (result['fee'] != null) {
          body['cancellationFee'] = result['fee'];
        }
        await apiClient.patch('/rides/${_currentRide.id}/status', body);
        setState(() {
          _currentRide = _currentRide.copyWith(
            status: RideStatus.cancelled,
            cancellationReason: result['reason'] as String?,
            cancellationFee: result['fee'] as double?,
            cancelledBy: authState.user?.name,
          );
        });
        _showSuccessMessage('Ride cancelled');
      } catch (e) {
        _showErrorMessage('Failed to cancel ride: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rateRide(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => RateRideDialog(rideId: _currentRide.id),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final apiClient = context.read<AuthBloc>().apiClient;
        await apiClient.post('/rides/${_currentRide.id}/rate', {
          'rating': result['rating'],
          'comment': result['comment'],
        });
        setState(() {
          _currentRide = _currentRide.copyWith(
            rating: result['rating'] as int?,
            ratingComment: result['comment'] as String?,
          );
        });
        _showSuccessMessage('Thank you for your rating!');
      } catch (e) {
        _showErrorMessage('Failed to submit rating: $e');
      } finally {
        setState(() => _isLoading = false);
      }
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
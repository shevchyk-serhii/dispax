import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';

class RideDetailsScreen extends StatelessWidget {
  final Ride ride;
  final bool isClientView;

  const RideDetailsScreen({
    Key? key, 
    required this.ride, 
    this.isClientView = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isClientView ? 'My Ride #${ride.id}' : 'Ride #${ride.id}'),
        backgroundColor: isClientView ? Colors.green[600] : Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),
            
            // Route Information
            _buildRouteCard(),
            const SizedBox(height: 16),
            
            // Flight Information (if airport transfer)
            if (ride.isAirportTransfer) ...[
              _buildFlightCard(),
              const SizedBox(height: 16),
            ],
            
            // Client/Driver Information
            if (isClientView) 
              _buildDriverCard()
            else 
              _buildClientCard(),
            const SizedBox(height: 16),
            
            // Time Information
            _buildTimeCard(),
            const SizedBox(height: 24),
            
            // Action Buttons
            if (isClientView)
              _buildClientActionButtons(context)
            else
              _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    
    switch (ride.status) {
      case RideStatus.requested:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case RideStatus.assigned:
        statusColor = Colors.blue;
        statusIcon = Icons.assignment;
        break;
      case RideStatus.inProgress:
        statusColor = Colors.green;
        statusIcon = Icons.directions_car;
        break;
      case RideStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle;
        break;
      case RideStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  ride.statusDisplayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.from.address,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 2,
                height: 20,
                color: Colors.grey[300],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.to.address,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Flight Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (ride.flightIconData != null)
                  Icon(
                    ride.flightIconData,
                    size: 20,
                    color: ride.isArrival ? Colors.green : Colors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Flight Number and Type
            Row(
              children: [
                Icon(Icons.flight, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  '${ride.flightNumber} (${ride.flightTypeText})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Gate and Terminal
            if (ride.gate != null || ride.terminal != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _buildGateTerminalText(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Flight Time
            if (ride.flightTime != null) ...[
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(ride.flightTime!),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Flight Status
            if (ride.flightStatus != null) ...[
              Row(
                children: [
                  Text(ride.flightStatusIcon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(), width: 1),
                    ),
                    child: Text(
                      ride.flightStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildGateTerminalText() {
    if (ride.gate != null && ride.terminal != null) {
      return 'Gate ${ride.gate} (Terminal ${ride.terminal})';
    } else if (ride.gate != null) {
      return 'Gate ${ride.gate}';
    } else if (ride.terminal != null) {
      return 'Terminal ${ride.terminal}';
    }
    return '';
  }

  Color _getStatusColor() {
    if (ride.flightStatus == null) return Colors.grey;
    switch (ride.flightStatus!.toLowerCase()) {
      case 'on time':
        return Colors.green;
      case 'delayed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildClientCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  ride.clientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            if (ride.driverId != null) ...[
              Row(
                children: [
                  Icon(Icons.drive_eta, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Driver assigned',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Contact available after pickup',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Driver not assigned yet',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.purple[600], size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(ride.pickupDateTime),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (ride.status == RideStatus.assigned) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Start ride functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting ride...')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (ride.status == RideStatus.inProgress) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Complete ride functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completing ride...')),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Complete Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Contact Client button (always available for assigned/in-progress rides)
        if (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Contact client functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contacting client...')),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contact Client'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Navigation button (always available)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Open navigation app
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening navigation to ${ride.from.address}')),
              );
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Navigate'),
          ),
        ),
      ],
    );
  }

  Widget _buildClientActionButtons(BuildContext context) {
    return Column(
      children: [
        // Contact Support button (always available)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Contact support functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contacting support...')),
              );
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Driver contact (only when driver assigned and ride active)
        if (ride.driverId != null && 
            (ride.status == RideStatus.assigned || ride.status == RideStatus.inProgress)) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Contact driver functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contacting driver...')),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contact Driver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Track ride (only when in progress)
        if (ride.status == RideStatus.inProgress) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Track ride functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening ride tracking...')),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Track My Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Cancel ride (only when requested or assigned)
        if (ride.status == RideStatus.requested || ride.status == RideStatus.assigned) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Cancel ride functionality
                _showCancelDialog(context);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Ride'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride cancelled')),
              );
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
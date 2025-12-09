import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../core/navigation_helper.dart';
import '../../core/navigation_utils.dart';

class RideQuickActions extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onCallClient;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;

  const RideQuickActions({
    Key? key,
    required this.ride,
    this.onCallClient,
    this.onStartRide,
    this.onCompleteRide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onCallClient ?? () {
            // TODO: Implement call client functionality
          },
          icon: const Icon(Icons.phone, size: 20),
          color: Colors.green,
          tooltip: 'Call Client',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        IconButton(
          onPressed: () => _handleNavigation(context, ride),
          icon: const Icon(Icons.navigation, size: 20),
          color: Colors.blue,
          tooltip: 'Navigate',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Expanded(
          child: Container(
            alignment: Alignment.centerRight,
            child: _buildStatusButton(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(BuildContext context) {
    if (ride.status == RideStatus.assigned) {
      return ElevatedButton.icon(
        onPressed: onStartRide ?? () {
          // TODO: Implement start ride functionality
        },
        icon: const Icon(Icons.play_arrow, size: 14),
        label: const Text('Start', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(60, 32),
        ),
      );
    } else if (ride.status == RideStatus.inProgress) {
      return ElevatedButton.icon(
        onPressed: onCompleteRide ?? () {
          // TODO: Implement complete ride functionality
        },
        icon: const Icon(Icons.check, size: 14),
        label: const Text('Done', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(60, 32),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static void _handleNavigation(BuildContext context, Ride ride) async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Navigate to'),
            content: const Text('Choose navigation destination:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('pickup'),
                child: Text('Pickup: ${ride.from.address}'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('destination'),
                child: Text('Drop-off: ${ride.to.address}'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (choice == null) return;

      if (choice == 'pickup') {
        await NavigationUtils.openGoogleMapsNavigation(ride.from);
      } else if (choice == 'destination') {
        await NavigationUtils.openGoogleMapsNavigation(ride.to);
      }

      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          'Opening navigation in Google Maps...',
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          'Could not open navigation: $e',
          isError: true,
        );
      }
    }
  }
}
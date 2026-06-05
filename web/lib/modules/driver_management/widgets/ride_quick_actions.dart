import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../core/navigation_helper.dart';
import '../../core/navigation_utils.dart';
import '../../../constants/app_colors.dart';

class RideQuickActions extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onCallClient;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;

  const RideQuickActions({
    super.key,
    required this.ride,
    this.onCallClient,
    this.onStartRide,
    this.onCompleteRide,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onCallClient ?? () {

          },
          icon: const Icon(Icons.phone, size: 20),
          color: AppColors.success,
          tooltip: 'Call Client',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        IconButton(
          onPressed: () => _handleNavigation(context, ride),
          icon: const Icon(Icons.navigation, size: 20),
          color: AppColors.info,
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

        },
        icon: const Icon(Icons.play_arrow, size: 14),
        label: const Text('Start', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(60, 32),
        ),
      );
    } else if (ride.status == RideStatus.inProgress) {
      return ElevatedButton.icon(
        onPressed: onCompleteRide ?? () {

        },
        icon: const Icon(Icons.check, size: 14),
        label: const Text('Done', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
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
          return SimpleDialog(
            title: const Text('Navigate to'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('pickup'),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.success),
                  title: Text(ride.from.address),
                  subtitle: const Text('Google Maps — Pickup'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('destination'),
                child: ListTile(
                  leading: const Icon(Icons.flag, color: AppColors.error),
                  title: Text(ride.to.address),
                  subtitle: const Text('Google Maps — Drop-off'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('waze_pickup'),
                child: const ListTile(
                  leading: Icon(Icons.map, color: AppColors.accent),
                  title: Text('Waze — Pickup'),
                ),
              ),
            ],
          );
        },
      );

      if (choice == null) return;

      switch (choice) {
        case 'pickup':
          await NavigationUtils.openGoogleMapsNavigation(ride.from);
        case 'destination':
          await NavigationUtils.openGoogleMapsNavigation(ride.to);
        case 'waze_pickup':
          await NavigationUtils.openWazeNavigation(ride.from);
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
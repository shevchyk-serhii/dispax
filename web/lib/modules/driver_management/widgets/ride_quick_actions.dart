import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../core/navigation_helper.dart';
import '../../core/navigation_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';

class RideQuickActions extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onCallClient;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onViewDetails;

  const RideQuickActions({
    super.key,
    required this.ride,
    this.onCallClient,
    this.onStartRide,
    this.onCompleteRide,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusButton = _buildStatusButton(context);

    return Row(
      children: [
        // Icon-only utility actions
        _buildIconAction(
          icon: Icons.phone_rounded,
          color: AppColors.success,
          tooltip: 'Call Client',
          onPressed: onCallClient ?? () {},
        ),
        const SizedBox(width: 8),
        _buildIconAction(
          icon: Icons.navigation_rounded,
          color: AppColors.accent,
          tooltip: 'Navigate',
          onPressed: () => _handleNavigation(context, ride),
        ),
        const SizedBox(width: 8),
        // Details ghost button
        _buildGhostButton(
          context,
          icon: Icons.info_outline_rounded,
          label: 'Details',
          onPressed: onViewDetails ?? () {},
        ),
        const Spacer(),
        // Primary status action
        if (statusButton != null) statusButton,
      ],
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppStyles.labelSmall.copyWith(
              color: onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusButton(BuildContext context) {
    if (ride.status == RideStatus.assigned) {
      return _buildActionButton(
        icon: Icons.play_circle_rounded,
        label: 'Start',
        color: AppColors.accent,
        onPressed: onStartRide ?? () {},
      );
    }
    if (ride.status == RideStatus.inProgress) {
      return _buildActionButton(
        icon: Icons.check_circle_rounded,
        label: 'Complete',
        color: AppColors.success,
        onPressed: onCompleteRide ?? () {},
      );
    }
    return null;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: AppStyles.labelMedium),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }

  static void _handleNavigation(BuildContext context, Ride ride) async {
    try {
      final choice = await showAdaptiveDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Navigate to'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('pickup'),
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: AppColors.success,
                  ),
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

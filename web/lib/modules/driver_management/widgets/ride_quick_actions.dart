import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
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
  final VoidCallback? onConfirmRide;
  final VoidCallback? onRejectRide;

  const RideQuickActions({
    super.key,
    required this.ride,
    this.onCallClient,
    this.onStartRide,
    this.onCompleteRide,
    this.onViewDetails,
    this.onConfirmRide,
    this.onRejectRide,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusButton = _buildStatusButton(context, l10n);

    // Wrap (not Row) so the action group flows onto a second line instead of
    // overflowing on a narrow screen — overflow-proof by construction, for any
    // locale/label length (German labels like "Fahrt abschließen" are longer
    // than English and overflowed a fixed Row). Trade-off: the status button is
    // no longer right-pinned via a Spacer; it sits inline and wraps when cramped.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Icon-only utility actions
        _buildIconAction(
          icon: Icons.phone_rounded,
          color: AppColors.success,
          tooltip: l10n.callClientTooltip,
          onPressed: onCallClient ?? () {},
        ),
        _buildIconAction(
          icon: Icons.navigation_rounded,
          color: AppColors.accent,
          tooltip: l10n.navigateTooltip,
          onPressed: () => NavigationUtils.showNavigateToDialog(context, ride),
        ),
        // Duplicate this ride into a new, pre-filled create-ride form.
        _buildIconAction(
          icon: Icons.copy_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          tooltip: l10n.duplicateRideAction,
          onPressed: () => NavigationUtils.duplicateRide(context, ride),
        ),
        // Details ghost button
        _buildGhostButton(
          context,
          icon: Icons.info_outline_rounded,
          label: l10n.viewDetailsMenu,
          onPressed: onViewDetails ?? () {},
        ),
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

  Widget? _buildStatusButton(BuildContext context, AppLocalizations l10n) {
    if (ride.status == RideStatus.assigned) {
      // Assigned but not confirmed: show Confirm and Reject buttons.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            icon: Icons.check_circle_rounded,
            label: 'Confirm',
            color: AppColors.success,
            onPressed: onConfirmRide ?? () {},
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.cancel_rounded,
            label: 'Reject',
            color: AppColors.error,
            onPressed: onRejectRide ?? () {},
          ),
        ],
      );
    }
    if (ride.status == RideStatus.confirmed) {
      // Confirmed: driver can now start the ride.
      return _buildActionButton(
        icon: Icons.play_circle_rounded,
        label: l10n.start,
        color: AppColors.accent,
        onPressed: onStartRide ?? () {},
      );
    }
    if (ride.status == RideStatus.inProgress) {
      return _buildActionButton(
        icon: Icons.check_circle_rounded,
        label: l10n.completeRideButton,
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
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: AppStyles.labelMedium,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }
}

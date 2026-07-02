import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../modules/ride_management/models/payment_method.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/ride_management/helpers/flight_status_l10n.dart';

class AssignmentDialog extends StatelessWidget {
  final Ride ride;
  final String driverLabel;
  final String driverId;
  final List<Ride> conflicts;
  final VoidCallback onConfirm;

  const AssignmentDialog({
    super.key,
    required this.ride,
    required this.driverLabel,
    required this.driverId,
    required this.conflicts,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasConflicts = conflicts.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Graphite header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: AppDimensions.paddingMedium,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.assignRideDialogTitle(ride.clientName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ride details card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: AppStyles.cardDecorationOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(l10n.rideDetailsLabel),
                          const SizedBox(height: 8),
                          _infoRow(
                            context,
                            icon: Icons.person_outline,
                            label: l10n.clientLabel,
                            value: ride.clientName,
                            isDark: isDark,
                          ),
                          _infoRow(
                            context,
                            icon: Icons.access_time_outlined,
                            label: l10n.timeLabel,
                            value: DateFormat(
                              'dd.MM.yyyy HH:mm',
                            ).format(ride.pickupDateTime),
                            isDark: isDark,
                          ),
                          _infoRow(
                            context,
                            icon: Icons.place_outlined,
                            label: l10n.fromLabel,
                            value: ride.from.address,
                            isDark: isDark,
                          ),
                          _infoRow(
                            context,
                            icon: Icons.flag_outlined,
                            label: l10n.toLabel,
                            value: ride.to.address,
                            isDark: isDark,
                          ),
                          if (ride.flightNumber != null)
                            _infoRow(
                              context,
                              icon: Icons.flight,
                              label: l10n.flightLabel,
                              // Show gate/terminal/status next to the number so
                              // the dispatcher sees where the ride is going
                              // before picking a driver, not just the flight no.
                              value: _flightDetails(l10n, ride),
                              isDark: isDark,
                            ),
                          if (ride.price != null)
                            _infoRow(
                              context,
                              icon: Icons.euro_outlined,
                              label: l10n.fareLabel,
                              value: '€${ride.price?.toStringAsFixed(2) ?? ''}',
                              isDark: isDark,
                              accent: true,
                            ),
                          if (PaymentMethod.labelForWire(
                                ride.paymentMethod,
                                l10n,
                              ) !=
                              null)
                            _infoRow(
                              context,
                              icon: Icons.payments_outlined,
                              label: l10n.paymentMethodSelectLabel,
                              value:
                                  PaymentMethod.labelForWire(
                                    ride.paymentMethod,
                                    l10n,
                                  ) ??
                                  '',
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Assign-to card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.rideAssignedBgDark
                            : AppColors.rideAssignedBg,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.rideAssignedBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.accent.withValues(
                              alpha: 0.15,
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.assigningToLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.rideAssignedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driverLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Conflict warning
                    if (hasConflicts) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.rideCancelledBgDark
                              : AppColors.errorBg,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                          border: Border.all(
                            color: AppColors.rideCancelledBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.scheduleConflictsCount(conflicts.length),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.errorStrong,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...conflicts.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${DateFormat('HH:mm').format(c.pickupDateTime)} — '
                                  '${c.from.address} → ${c.to.address}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.rideCancelledText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderPrimary,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: AppStyles.textButtonStyleOf(context),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: hasConflicts
                        ? FilledButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium,
                              ),
                            ),
                          )
                        : AppStyles.accentButtonStyle,
                    icon: Icon(
                      hasConflicts ? Icons.warning_amber_rounded : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      hasConflicts
                          ? l10n.assignAnyway
                          : l10n.assignDriverButton,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
        letterSpacing: 0.8,
      ),
    );
  }

  /// Flight number plus gate/terminal/status on one line. Mirrors
  /// [Ride.fullFlightInfo] but drops its leading ✈ glyph because this row
  /// already renders a flight icon, and skips the 🛬/🛫 status glyph to keep
  /// the value plain text inside [_infoRow].
  String _flightDetails(AppLocalizations l10n, Ride ride) {
    final parts = <String>[ride.flightNumber ?? ''];
    // A remote stand has no real code → its label is self-describing (no "Gate" prefix).
    final gate = l10n.localizedGate(ride);
    final gateText = ride.isRemoteGate
        ? gate
        : (gate != null ? '${l10n.gateLabel} $gate' : null);
    if (gateText != null && ride.terminal != null) {
      parts.add('$gateText (${l10n.terminalLabel} ${ride.terminal})');
    } else if (gateText != null) {
      parts.add(gateText);
    } else if (ride.terminal != null) {
      parts.add('${l10n.terminalLabel} ${ride.terminal}');
    }
    final statusText = l10n.localizedFlightStatus(ride.flightStatus);
    if (statusText.isNotEmpty) {
      parts.add(statusText);
    }
    return parts.join(' • ');
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent
                    ? AppColors.accent
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

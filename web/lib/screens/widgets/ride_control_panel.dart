import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/helpers/flight_status_l10n.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_styles.dart';
import '../../modules/core/date_utils.dart';
import '../../modules/ride_management/models/payment_method.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../utils/ride_status_styles.dart';

/// Bottom "active ride" card on the Driver Dashboard map.
///
/// Extracted from `DriverMapScreen` so it can be rendered (and tested) without
/// the screen's Mapbox/geolocation/WebSocket dependencies. All text follows the
/// active theme via `colorScheme.onSurface`, and the status chip reuses
/// [RideStatusStyles.createStatusBadge] so it stays legible in dark mode.
class RideControlPanel extends StatelessWidget {
  const RideControlPanel({
    super.key,
    required this.ride,
    required this.onStartRide,
    required this.onCompleteRide,
    this.airportCheckpoint,
  });

  final Ride ride;
  final VoidCallback onStartRide;
  final VoidCallback onCompleteRide;

  /// Optional airport checkpoint progress widget, supplied by the screen which
  /// owns the live checkpoint state. Rendered only when provided.
  final Widget? airportCheckpoint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final paymentLabel = PaymentMethod.labelForWire(ride.paymentMethod, l10n);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.radiusLarge),
          topRight: Radius.circular(AppDimensions.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ride.clientName,
                  style: AppStyles.titleMedium.copyWith(color: onSurface),
                ),
              ),
              RideStatusStyles.createStatusBadge(
                ride.status,
                context: context,
                fontSize: 10,
                iconSize: AppDimensions.iconSmall,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          Row(
            children: [
              Icon(
                Icons.schedule,
                color: onSurfaceVariant,
                size: AppDimensions.iconSmall,
              ),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                AppDateUtils.formatDateTime(ride.pickupDateTime),
                style: AppStyles.bodyMedium.copyWith(color: onSurface),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          Row(
            children: [
              Icon(
                Icons.route,
                color: onSurfaceVariant,
                size: AppDimensions.iconSmall,
              ),
              const SizedBox(width: AppDimensions.paddingSmall),
              Expanded(
                child: Text(
                  '${ride.from.address} → ${ride.to.address}',
                  style: AppStyles.bodyMedium.copyWith(color: onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (ride.price != null) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              children: [
                Icon(
                  Icons.euro,
                  color: onSurfaceVariant,
                  size: AppDimensions.iconSmall,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  // Currency symbol + amount is locale-neutral; drop a trailing
                  // ".0" so a whole-euro fare reads "45", not "45.0".
                  '€${ride.price! == ride.price!.roundToDouble() ? ride.price!.toStringAsFixed(0) : ride.price}',
                  style: AppStyles.bodyMedium.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          if (paymentLabel != null) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: onSurfaceVariant,
                  size: AppDimensions.iconSmall,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  paymentLabel,
                  style: AppStyles.bodyMedium.copyWith(color: onSurface),
                ),
              ],
            ),
          ],

          if (ride.etaMinutes != null) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: AppColors.accent,
                  size: AppDimensions.iconSmall,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  '~${ride.etaMinutes} min to client',
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          if (ride.isAirportTransfer) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              children: [
                Icon(
                  Icons.flight,
                  color: onSurfaceVariant,
                  size: AppDimensions.iconSmall,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(() {
                  final flightInfo = l10n.fullFlightInfoLocalized(ride);
                  final statusText = l10n.localizedFlightStatus(
                    ride.flightStatus,
                  );
                  return statusText.isEmpty
                      ? flightInfo
                      : '$flightInfo • ${ride.flightStatusIcon} $statusText';
                }(), style: AppStyles.bodyMedium.copyWith(color: onSurface)),
              ],
            ),
          ],

          if (airportCheckpoint != null) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            airportCheckpoint!,
          ],

          const SizedBox(height: AppDimensions.paddingLarge),

          if (ride.status == RideStatus.assigned)
            ElevatedButton(
              onPressed: onStartRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Start Ride'),
            )
          else if (ride.status == RideStatus.inProgress)
            ElevatedButton(
              onPressed: onCompleteRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clientColor,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Complete Ride'),
            ),
        ],
      ),
    );
  }
}

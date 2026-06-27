import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../modules/ride_management/helpers/flight_status_l10n.dart';
import '../../../../modules/ride_management/models/ride.dart';
import '../../../../constants/app_colors.dart';

/// Compact, self-hiding badges that surface the rich [Ride] fields the
/// schedule cards never showed before (flight, airport checkpoint, VIP,
/// payment, special requirements). Each badge returns an empty widget when its
/// field is absent, so callers can drop them in unconditionally.
///
/// Designed to be reused across Day / Week / Month views and the dispatcher
/// panel (see plan variants B/C/D).
class RideBadges {
  const RideBadges._();

  /// The chip row shown under the time/price line: flight, checkpoint, VIP,
  /// payment. Returns [SizedBox.shrink] when none apply.
  static Widget chips(BuildContext context, Ride ride) {
    final badges = <Widget>[
      flight(context, ride),
      checkpoint(context, ride),
      vip(context, ride),
      payment(context, ride),
    ].where((w) => w is! SizedBox).toList();

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: badges),
    );
  }

  /// Flight / airport-transfer badge: ✈ arrival/departure, flight number,
  /// gate/terminal and flight status. Delayed/cancelled flights are coloured.
  static Widget flight(BuildContext context, Ride ride) {
    if (!ride.isAirportTransfer || ride.flightNumber == null) {
      return const SizedBox.shrink();
    }

    Color color = AppColors.info;
    switch (ride.flightStatus?.toLowerCase()) {
      case 'delayed':
        color = AppColors.warning;
      case 'cancelled':
        color = AppColors.error;
    }

    final base = ride.fullFlightInfo.isNotEmpty
        ? ride.fullFlightInfo
        : '${ride.flightTypeText} ${ride.flightNumber}';
    final statusText = AppLocalizations.of(
      context,
    )!.localizedFlightStatus(ride.flightStatus);
    final label = statusText.isEmpty
        ? base
        : '$base • ${ride.flightStatusIcon} $statusText';

    return _Badge(
      icon: ride.flightIconData ?? Icons.flight,
      label: label,
      color: color,
    );
  }

  /// Where the client currently is at the airport: landed / arrivals hall /
  /// terminal exit.
  static Widget checkpoint(BuildContext context, Ride ride) {
    final cp = ride.airportCheckpoint;
    if (cp == null || cp.isEmpty) return const SizedBox.shrink();

    final (String label, IconData icon) = switch (cp.toLowerCase()) {
      'landed' => ('Landed', Icons.flight_land),
      'arrivals_hall' => ('In arrivals hall', Icons.meeting_room),
      'terminal_exit' => ('At exit', Icons.exit_to_app),
      _ => (cp, Icons.place),
    };

    return _Badge(icon: icon, label: label, color: AppColors.accent);
  }

  /// VIP ride marker.
  static Widget vip(BuildContext context, Ride ride) {
    if (!ride.isVipRide) return const SizedBox.shrink();
    return const _Badge(
      icon: Icons.star,
      label: 'VIP',
      color: AppColors.warning,
    );
  }

  /// Payment state + method (e.g. "Paid · Card", "Unpaid").
  static Widget payment(BuildContext context, Ride ride) {
    final status = ride.paymentStatus;
    if (status == null || status.isEmpty) return const SizedBox.shrink();

    final paid = status.toLowerCase() == 'paid';
    final method = ride.paymentMethod;
    final label = method != null && method.isNotEmpty
        ? '${paid ? 'Paid' : 'Unpaid'} · $method'
        : (paid ? 'Paid' : 'Unpaid');

    return _Badge(
      icon: paid ? Icons.check_circle_outline : Icons.payments_outlined,
      label: label,
      color: paid ? AppColors.success : AppColors.textSecondary,
    );
  }

  /// Tiny icon markers summarising a *set* of rides (a day in week/month
  /// views): airport, VIP, special requirements. Each icon appears at most
  /// once. Returns [SizedBox.shrink] when none apply.
  static Widget dayMarkers(
    BuildContext context,
    Iterable<Ride> rides, {
    double size = 12,
  }) {
    final hasAirport = rides.any((r) => r.isAirportTransfer);
    final hasVip = rides.any((r) => r.isVipRide);
    final hasRequirements = rides.any(
      (r) =>
          (r.specialRequirements != null &&
              r.specialRequirements!.isNotEmpty) ||
          (r.notes != null && r.notes!.isNotEmpty),
    );

    final icons = <Widget>[
      if (hasAirport) Icon(Icons.flight, size: size, color: AppColors.info),
      if (hasVip) Icon(Icons.star, size: size, color: AppColors.warning),
      if (hasRequirements)
        Icon(Icons.priority_high, size: size, color: AppColors.warning),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  /// Corner icon markers for a single ride block in the (cramped) week
  /// timeline: airport / VIP / special requirements.
  static Widget blockMarkers(Ride ride, {double size = 10}) {
    final hasRequirements =
        (ride.specialRequirements != null &&
            ride.specialRequirements!.isNotEmpty) ||
        (ride.notes != null && ride.notes!.isNotEmpty);

    final icons = <Widget>[
      if (ride.isAirportTransfer)
        Icon(Icons.flight, size: size, color: Colors.white),
      if (ride.isVipRide) Icon(Icons.star, size: size, color: Colors.white),
      if (hasRequirements)
        Icon(Icons.priority_high, size: size, color: Colors.white),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  /// One-line plain-text summary of a ride for tooltips/hover (week view).
  static String tooltip(BuildContext context, Ride ride) {
    final statusText = AppLocalizations.of(
      context,
    )!.localizedFlightStatus(ride.flightStatus);
    final flightLine = statusText.isEmpty
        ? ride.fullFlightInfo
        : '${ride.fullFlightInfo} • ${ride.flightStatusIcon} $statusText';
    final parts = <String>[
      ride.clientName,
      if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty) flightLine,
      if (ride.isVipRide) 'VIP',
      if (ride.price != null) '€${ride.price!.toStringAsFixed(2)}',
      if (ride.specialRequirements != null &&
          ride.specialRequirements!.isNotEmpty)
        ride.specialRequirements!,
      ride.to.address,
    ];
    return parts.join(' • ');
  }

  /// Special requirements / notes line, shown only when present.
  static Widget requirements(BuildContext context, Ride ride) {
    final parts = <String>[
      if (ride.specialRequirements != null &&
          ride.specialRequirements!.isNotEmpty)
        ride.specialRequirements!,
      if (ride.notes != null && ride.notes!.isNotEmpty) ride.notes!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.priority_high, size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' • '),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

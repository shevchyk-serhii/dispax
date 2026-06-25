import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../modules/ride_management/models/payment_method.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/core/widgets/ride_info_row.dart';

/// Dialog body for the "new ride assigned" confirmation dialog.
///
/// When [ride] is non-null, renders structured ride details (client, pickup,
/// destination, pickup time, price, flight info) using [RideInfoRow] widgets,
/// matching the layout conventions of [TodayRideCard._buildContent].
///
/// When [ride] is null (fetch failed), falls back to the generic text so the
/// driver can still make an accept/decline decision.
class RideAssignedDetails extends StatelessWidget {
  final Ride? ride;

  const RideAssignedDetails({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final r = ride;
    if (r == null) {
      return const Text('You have been assigned a new ride. Do you accept it?');
    }

    final rows = <Widget>[
      RideInfoRow(icon: Icons.person, label: 'Client', text: r.clientName),
      const SizedBox(height: 12),
      RideInfoRow(
        icon: Icons.location_on,
        label: 'Pickup',
        text: r.from.address,
      ),
      const SizedBox(height: 12),
      RideInfoRow(icon: Icons.flag, label: 'Destination', text: r.to.address),
      const SizedBox(height: 12),
      RideInfoRow(
        icon: Icons.access_time,
        label: 'Pickup time',
        text: DateFormat.Hm().format(r.pickupDateTime),
      ),
    ];

    if (r.price != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(
        RideInfoRow(
          icon: Icons.euro,
          label: 'Price',
          text: '€${r.price!.toStringAsFixed(2)}',
        ),
      );
    }

    final paymentLabel = PaymentMethod.labelForWire(
      r.paymentMethod,
      AppLocalizations.of(context)!,
    );
    if (paymentLabel != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(
        RideInfoRow(
          icon: Icons.payments_outlined,
          label: AppLocalizations.of(context)!.paymentMethodSelectLabel,
          text: paymentLabel,
        ),
      );
    }

    if (r.isAirportTransfer && r.fullFlightInfo.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(
        RideInfoRow(
          icon: Icons.flight,
          label: 'Flight',
          text: r.fullFlightInfo,
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

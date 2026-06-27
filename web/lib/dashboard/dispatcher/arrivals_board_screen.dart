import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/flight_management/models/muc_flight.dart';
import '../../modules/flight_management/services/arrivals_board_service.dart';
import '../../modules/ride_management/helpers/flight_status_l10n.dart';

/// Dispatcher arrivals board: the live MUC arrivals (flight, origin, scheduled/estimated
/// time, terminal, localized status), fetched from GET /api/flights/arrivals.
class ArrivalsBoardScreen extends StatefulWidget {
  const ArrivalsBoardScreen({super.key});

  @override
  State<ArrivalsBoardScreen> createState() => _ArrivalsBoardScreenState();
}

class _ArrivalsBoardScreenState extends State<ArrivalsBoardScreen> {
  late Future<List<MucFlight>> _future;

  @override
  void initState() {
    super.initState();
    _future = ArrivalsBoardService.instance.getArrivals();
  }

  Future<void> _refresh() async {
    final next = ArrivalsBoardService.instance.getArrivals();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.arrivalsBoardTitle)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MucFlight>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final flights = snapshot.data ?? const <MucFlight>[];
            if (flights.isEmpty) {
              // ListView so pull-to-refresh works even when empty.
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      l10n.noArrivalsFound,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: flights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _ArrivalRow(flight: flights[i], l10n: l10n),
            );
          },
        ),
      ),
    );
  }
}

class _ArrivalRow extends StatelessWidget {
  final MucFlight flight;
  final AppLocalizations l10n;

  const _ArrivalRow({required this.flight, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = flight.estimatedTime ?? flight.scheduledTime;
    final timeText = time != null ? DateFormat.Hm().format(time) : '--:--';
    final statusText = l10n.localizedFlightStatus(flight.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.flight_land, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        flight.flightNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (flight.origin != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '← ${flight.origin}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (flight.airline != null) flight.airline!,
                      if (flight.terminal != null)
                        'Terminal ${flight.terminal!}',
                    ].join(' · '),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                if (statusText.isNotEmpty)
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: flight.isDelayed
                          ? AppColors.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

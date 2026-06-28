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
  late DateTime _date;
  late Future<List<MucFlight>> _future;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _future = _load();
  }

  Future<List<MucFlight>> _load() {
    final iso = DateFormat('yyyy-MM-dd').format(_date);
    return ArrivalsBoardService.instance.getArrivals(date: iso);
  }

  void _setDate(DateTime date) {
    setState(() {
      // Compare by calendar day only.
      _date = DateTime(date.year, date.month, date.day);
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null) _setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.arrivalsBoardTitle)),
      body: Column(
        children: [
          ArrivalsDateBar(
            date: _date,
            onPrev: () => _setDate(_date.subtract(const Duration(days: 1))),
            onNext: () => _setDate(_date.add(const Duration(days: 1))),
            onTap: _pickDate,
          ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    return RefreshIndicator(
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
    );
  }
}

/// Date selector bar: ‹ prev day · tappable date (opens a date picker) · next day ›.
class ArrivalsDateBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  const ArrivalsDateBar({
    super.key,
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat('EEE, d MMM', locale).format(date);
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
              tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            ),
          ],
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

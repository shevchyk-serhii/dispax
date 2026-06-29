import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/flight_management/models/muc_flight.dart';
import '../../modules/flight_management/services/arrivals_board_service.dart';
import '../../modules/flight_management/widgets/flight_progress_bar.dart';
import '../../modules/ride_management/helpers/flight_status_l10n.dart';

/// Dispatcher arrivals board: the live MUC arrivals (flight, origin, scheduled/estimated
/// time, terminal, localized status), fetched from GET /api/flights/arrivals.
class ArrivalsBoardScreen extends StatefulWidget {
  /// Override the data source in tests; production uses [ArrivalsBoardService.instance].
  final ArrivalsBoardService? service;

  const ArrivalsBoardScreen({super.key, this.service});

  @override
  State<ArrivalsBoardScreen> createState() => _ArrivalsBoardScreenState();
}

class _ArrivalsBoardScreenState extends State<ArrivalsBoardScreen> {
  late DateTime _date;
  late Future<List<MucFlight>> _future;
  final _searchController = TextEditingController();
  bool _searching = false;

  // The board list has no gate (it lives on each flight's detail page). We lazily look it up for the
  // rows that actually get built (ListView.builder builds ~visible only), cache by flight number, and
  // re-render the row with the resolved gate. Requested-but-not-yet-resolved numbers are tracked so a
  // flight is fetched at most once even while the user scrolls.
  final Map<String, String> _gateByFlight = {};
  final Set<String> _gateRequested = {};

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ArrivalsBoardService get _service =>
      widget.service ?? ArrivalsBoardService.instance;

  Future<List<MucFlight>> _load() {
    final iso = DateFormat('yyyy-MM-dd').format(_date);
    return _service.getArrivals(date: iso);
  }

  void _setDate(DateTime date) {
    setState(() {
      // Compare by calendar day only.
      _date = DateTime(date.year, date.month, date.day);
      _gateByFlight.clear(); // gates are per-date
      _gateRequested.clear();
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _gateByFlight.clear();
      _gateRequested.clear();
      _future = next;
    });
    await next;
  }

  /// Lazily resolve the gate for a row being built. Fetches once per flight (for the current date)
  /// via /flights/lookup and re-renders with the gate. No-op once known/requested.
  void _ensureGate(MucFlight flight) {
    final n = flight.flightNumber;
    if (flight.gate != null ||
        _gateByFlight.containsKey(n) ||
        _gateRequested.contains(n)) {
      return;
    }
    _gateRequested.add(n);
    final iso = DateFormat('yyyy-MM-dd').format(_date);
    _service.lookupFlight(flightNumber: n, date: iso, isArrival: true).then((
      found,
    ) {
      if (!mounted) return;
      final gate = found?.gate;
      if (gate != null) setState(() => _gateByFlight[n] = gate);
    });
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

  /// The board has no gate (it lives on the flight's detail page). Tapping a row fetches the single
  /// flight WITH its gate via /flights/lookup and shows it in a bottom sheet. The board row is used
  /// as the immediate fallback while the gate-bearing lookup is in flight (or if it fails).
  void _openFlightDetails(MucFlight row, AppLocalizations l10n) {
    final iso = DateFormat('yyyy-MM-dd').format(_date);
    final lookup = _service.lookupFlight(
      flightNumber: row.flightNumber,
      date: iso,
      isArrival: true,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FlightDetailsSheet(row: row, lookup: lookup, l10n: l10n),
    );
  }

  /// Look up a single flight by its number (for the selected date) and show its details — incl. the
  /// gate, which the board list does not carry. Empty input is ignored; a not-found result shows a snackbar.
  Future<void> _searchByNumber(AppLocalizations l10n) async {
    final number = _searchController.text.trim();
    if (number.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final iso = DateFormat('yyyy-MM-dd').format(_date);
    final flight = await _service.lookupFlight(
      flightNumber: number,
      date: iso,
      isArrival: true,
    );
    if (!mounted) return;
    setState(() => _searching = false);
    if (flight == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noArrivalsFound)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FlightDetailsSheet(
        row: flight,
        lookup: Future.value(flight),
        l10n: l10n,
      ),
    );
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _searchByNumber(l10n),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.flightNumberHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _searchByNumber(l10n),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
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
            itemBuilder: (context, i) {
              final flight = flights[i];
              _ensureGate(flight);
              return _ArrivalRow(
                flight: flight,
                resolvedGate: flight.gate ?? _gateByFlight[flight.flightNumber],
                l10n: l10n,
                onTap: () => _openFlightDetails(flight, l10n),
              );
            },
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

  /// Gate resolved lazily from the flight's detail page (the board list has none). Null until known.
  final String? resolvedGate;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _ArrivalRow({
    required this.flight,
    required this.resolvedGate,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = flight.estimatedTime ?? flight.scheduledTime;
    final timeText = time != null ? DateFormat.Hm().format(time) : '--:--';
    final statusText = l10n.localizedFlightStatus(flight.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        if (resolvedGate != null) 'Gate $resolvedGate',
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
      ),
    );
  }
}

/// Bottom sheet shown when a board row is tapped. The board row ([row]) renders immediately; the
/// [lookup] future resolves the same flight WITH its gate (the board has none) and replaces the
/// gate line once it arrives. A failed/empty lookup falls back to the row's data.
class FlightDetailsSheet extends StatelessWidget {
  final MucFlight row;
  final Future<MucFlight?> lookup;
  final AppLocalizations l10n;

  const FlightDetailsSheet({
    super.key,
    required this.row,
    required this.lookup,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = row.estimatedTime ?? row.scheduledTime;
    final timeText = time != null ? DateFormat.Hm().format(time) : '--:--';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_land, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  row.flightNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                if (row.origin != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '← ${row.origin}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Flight phase stepper (arrivals board → all rows are arrivals).
            Builder(
              builder: (context) {
                final bar = FlightProgressBar(
                  status: row.status,
                  isArrival: true,
                  delayMinutes: row.delayMinutes,
                  isDelayed: row.isDelayed,
                );
                return bar.isVisible
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: bar,
                      )
                    : const SizedBox.shrink();
              },
            ),
            _DetailLine(
              label: l10n.statusLabel,
              value: l10n.localizedFlightStatus(row.status),
            ),
            if (row.airline != null)
              _DetailLine(label: l10n.flightLabel, value: row.airline!),
            if (row.terminal != null)
              _DetailLine(label: l10n.terminalLabel, value: row.terminal!),
            // The gate comes from the per-flight lookup; show a spinner until it resolves.
            FutureBuilder<MucFlight?>(
              future: lookup,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${l10n.gateLabel}: ',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  );
                }
                final gate = snapshot.data?.gate ?? row.gate;
                // A remote (apron) stand shows as the localized "bus gate" label, not "REMOTE".
                final gateText = gate == null
                    ? l10n.gateNotPublished
                    : (gate.trim().toUpperCase() == 'REMOTE'
                          ? l10n.gateRemote
                          : gate);
                return _DetailLine(label: l10n.gateLabel, value: gateText);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: scheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

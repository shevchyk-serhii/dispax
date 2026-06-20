/// FlightBoardPanel — Dispatcher flight board widget.
///
/// Shows arrivals/departures for Munich Airport in a table format with
/// Flight | Origin | Sched. | Status | Linked ride columns.
///
/// Data source: FlightService (reads from backend /flights/munich/arrivals and
/// /flights/munich/departures endpoints). Linked-ride lookup is done via the
/// current RideBloc state matching on flightNumber.
///
/// TODO: When auto-sync is implemented on the backend (webhook / WS push),
/// remove the manual refresh and wire to a flight WS event instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/flight_management/services/flight_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

// ─── Status helpers ────────────────────────────────────────────────────────

enum _FlightStatusKind { onTime, delayed, boarding, cancelled, unknown }

Color _badgeFgColor(_FlightStatusKind kind) {
  switch (kind) {
    case _FlightStatusKind.onTime:
      return const Color(0xFF22C55E);
    case _FlightStatusKind.delayed:
      return const Color(0xFFEF4444);
    case _FlightStatusKind.boarding:
      return const Color(0xFF3B82F6);
    case _FlightStatusKind.cancelled:
      return const Color(0xFF6B7280);
    case _FlightStatusKind.unknown:
      return const Color(0xFF6B7280);
  }
}

Color _badgeBgColor(_FlightStatusKind kind, bool isDark) {
  final fg = _badgeFgColor(kind);
  return isDark ? fg.withValues(alpha: 0.18) : fg.withValues(alpha: 0.1);
}

String _badgeLabel(_FlightStatusKind kind, String? raw) {
  switch (kind) {
    case _FlightStatusKind.onTime:
      return 'On time';
    case _FlightStatusKind.delayed:
      if (raw != null) {
        final m = RegExp(r'\d+').firstMatch(raw);
        if (m != null) return '+${m.group(0)}min';
      }
      return 'Delayed';
    case _FlightStatusKind.boarding:
      return 'Boarding';
    case _FlightStatusKind.cancelled:
      return 'Cancelled';
    case _FlightStatusKind.unknown:
      return raw ?? 'Unknown';
  }
}

// ─── FlightBoardPanel ─────────────────────────────────────────────────────────

class FlightBoardPanel extends StatefulWidget {
  const FlightBoardPanel({super.key});

  @override
  State<FlightBoardPanel> createState() => _FlightBoardPanelState();
}

class _FlightBoardPanelState extends State<FlightBoardPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FlightData> _arrivals = [];
  List<FlightData> _departures = [];
  bool _isLoading = false;
  DateTime? _lastRefreshed;

  // FlightService uses the public backend proxy — no auth token needed for
  // flight data. It calls /flights/munich/{arrivals|departures}.
  final FlightService _flightService = FlightService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFlights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFlights() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _flightService.getMunichArrivals(hours: 2),
        _flightService.getMunichDepartures(hours: 2),
      ]);
      if (!mounted) return;
      setState(() {
        _arrivals = results[0];
        _departures = results[1];
        _lastRefreshed = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading flights: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Graphite header ──────────────────────────────────────────────────
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMedium,
                      AppDimensions.paddingMedium,
                      AppDimensions.paddingSmall,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.flight_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Flights · Munich Airport',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.sync_rounded,
                                    color: Colors.white60,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _lastRefreshed != null
                                        ? 'auto-synced · refreshed ${DateFormat('HH:mm').format(_lastRefreshed!)}'
                                        : 'auto-synced',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Refresh flights',
                          onPressed: _isLoading ? null : _loadFlights,
                        ),
                      ],
                    ),
                  ),
                  // Tab bar inside graphite header
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_land, size: 15),
                            SizedBox(width: 5),
                            Text('Arrivals'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_takeoff, size: 15),
                            SizedBox(width: 5),
                            Text('Departures'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTable(_arrivals, isArrival: true, isDark: isDark),
                    _buildTable(_departures, isArrival: false, isDark: isDark),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Flight table ─────────────────────────────────────────────────────────

  Widget _buildTable(
    List<FlightData> flights, {
    required bool isArrival,
    required bool isDark,
  }) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArrival ? Icons.flight_land : Icons.flight_takeoff,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isArrival ? 'arrivals' : 'departures'} in the next 2h',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Snapshot of rides for linked-ride lookup
    final rides = context.watch<RideBloc>().state.rides;

    return RefreshIndicator(
      onRefresh: _loadFlights,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Column header ─────────────────────────────────────────────
            Container(
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: 10,
              ),
              child: const Row(
                children: [
                  _ColHeader('Flight', flex: 2),
                  _ColHeader('Origin / Dest.', flex: 3),
                  _ColHeader('Sched.', flex: 2),
                  _ColHeader('Status', flex: 2),
                  _ColHeader('Linked ride', flex: 3),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // ── Rows ──────────────────────────────────────────────────────
            ...flights.map(
              (f) => _buildRow(
                f,
                isArrival: isArrival,
                rides: rides,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    FlightData flight, {
    required bool isArrival,
    required List<Ride> rides,
    required bool isDark,
  }) {
    final time = isArrival ? flight.arrivalTime : flight.departureTime;
    final airport = isArrival
        ? flight.estDepartureAirport
        : flight.estArrivalAirport;
    final callsign = flight.callsign.trim().isNotEmpty
        ? flight.callsign.trim()
        : flight.icao24;
    final timeStr = DateFormat('HH:mm').format(time);

    // Status — FlightData from OpenSky does not include a status string;
    // use 'unknown' as default. Real status would come from a richer API.
    // TODO: wire to a flight-status API or dispatcher-entered status when
    // backend provides it.
    const statusKind = _FlightStatusKind.unknown;

    // Match ride by flight number (case-insensitive)
    final linkedRide = rides
        .where(
          (r) =>
              r.flightNumber != null &&
              r.flightNumber!.toUpperCase() == callsign.toUpperCase(),
        )
        .firstOrNull;

    final badgeFg = _badgeFgColor(statusKind);
    final badgeBg = _badgeBgColor(statusKind, isDark);

    return Column(
      children: [
        Container(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
            vertical: 12,
          ),
          child: Row(
            children: [
              // Flight number
              Expanded(
                flex: 2,
                child: Text(
                  callsign,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Origin / destination
              Expanded(
                flex: 3,
                child: Text(
                  airport.isNotEmpty ? airport : '—',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Scheduled time
              Expanded(
                flex: 2,
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Status badge
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    border: Border.all(color: badgeFg.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _badgeLabel(statusKind, null),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Linked ride
              Expanded(
                flex: 3,
                child: linkedRide != null
                    ? Text(
                        '#${linkedRide.id.substring(0, linkedRide.id.length.clamp(0, 8))} · ${linkedRide.clientName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        '— not linked',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textLight,
                        ),
                      ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ],
    );
  }
}

// ─── Column header widget ────────────────────────────────────────────────────

class _ColHeader extends StatelessWidget {
  final String label;
  final int flex;

  const _ColHeader(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

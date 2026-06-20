import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/blocs.dart';
import '../modules/flight_management/services/flight_service.dart';
import '../modules/ride_management/models/ride.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

// ─── Flight status badge helpers ──────────────────────────────────────────────

enum _FlightStatus { onTime, delayed, boarding, cancelled, unknown }

_FlightStatus _parseStatus(String? raw) {
  if (raw == null) return _FlightStatus.unknown;
  final lower = raw.toLowerCase();
  if (lower.contains('on time') || lower == 'scheduled') {
    return _FlightStatus.onTime;
  }
  if (lower.contains('boarding')) return _FlightStatus.boarding;
  if (lower.contains('delay') || lower.contains('late')) {
    return _FlightStatus.delayed;
  }
  if (lower.contains('cancel')) return _FlightStatus.cancelled;
  return _FlightStatus.unknown;
}

Color _statusBadgeColor(_FlightStatus s) {
  switch (s) {
    case _FlightStatus.onTime:
      return const Color(0xFF22C55E);
    case _FlightStatus.delayed:
      return const Color(0xFFEF4444);
    case _FlightStatus.boarding:
      return const Color(0xFF3B82F6);
    case _FlightStatus.cancelled:
      return const Color(0xFF6B7280);
    case _FlightStatus.unknown:
      return const Color(0xFF6B7280);
  }
}

Color _statusBadgeBg(_FlightStatus s) {
  switch (s) {
    case _FlightStatus.onTime:
      return const Color(0xFFF0FDF4);
    case _FlightStatus.delayed:
      return const Color(0xFFFEF2F2);
    case _FlightStatus.boarding:
      return const Color(0xFFEFF6FF);
    case _FlightStatus.cancelled:
      return const Color(0xFFF3F4F6);
    case _FlightStatus.unknown:
      return const Color(0xFFF3F4F6);
  }
}

String _statusLabel(_FlightStatus s, String? raw) {
  switch (s) {
    case _FlightStatus.onTime:
      return 'On time';
    case _FlightStatus.delayed:
      // Try to extract delay minutes from raw, e.g. "+35min"
      if (raw != null) {
        final numMatch = RegExp(r'\d+').firstMatch(raw);
        if (numMatch != null) return '+${numMatch.group(0)}min';
      }
      return 'Delayed';
    case _FlightStatus.boarding:
      return 'Boarding';
    case _FlightStatus.cancelled:
      return 'Cancelled';
    case _FlightStatus.unknown:
      return raw ?? 'Unknown';
  }
}

// ─── FlightScreen ─────────────────────────────────────────────────────────────

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen>
    with SingleTickerProviderStateMixin {
  final FlightService _flightService = FlightService();
  late TabController _tabController;
  List<FlightData> _arrivals = [];
  List<FlightData> _departures = [];
  bool _isLoading = false;

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
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _flightService.getMunichArrivals(hours: 2),
        _flightService.getMunichDepartures(hours: 2),
      ]);
      setState(() {
        _arrivals = futures[0];
        _departures = futures[1];
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
      children: [
        // ── Graphite header ──────────────────────────────────────────────────
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.primary),
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
                      children: [
                        const Icon(
                          Icons.flight_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flights · Munich Airport',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 1),
                              Row(
                                children: [
                                  Icon(
                                    Icons.sync_rounded,
                                    color: Colors.white60,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'auto-synced',
                                    style: TextStyle(
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
                          onPressed: _loadFlights,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                  ),
                  // Tab bar
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
                            Icon(Icons.flight_land, size: 16),
                            SizedBox(width: 6),
                            Text('Arrivals'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_takeoff, size: 16),
                            SizedBox(width: 6),
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
                    _buildFlightTable(
                      _arrivals,
                      isArrival: true,
                      isDark: isDark,
                    ),
                    _buildFlightTable(
                      _departures,
                      isArrival: false,
                      isDark: isDark,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Flight table ─────────────────────────────────────────────────────────

  Widget _buildFlightTable(
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
              'No ${isArrival ? 'arrivals' : 'departures'} found',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Get ride list for linked-ride lookup
    final rides = context.watch<RideBloc>().state.rides;

    return RefreshIndicator(
      onRefresh: _loadFlights,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Table header ────────────────────────────────────────────────
            Container(
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: 10,
              ),
              child: Row(
                children: const [
                  _TableHeaderCell('Flight', flex: 2),
                  _TableHeaderCell('Origin / Dest.', flex: 3),
                  _TableHeaderCell('Sched.', flex: 2),
                  _TableHeaderCell('Status', flex: 2),
                  _TableHeaderCell('Linked ride', flex: 3),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // ── Table rows ──────────────────────────────────────────────────
            ...flights.map((flight) {
              final time = isArrival
                  ? flight.arrivalTime
                  : flight.departureTime;
              final airport = isArrival
                  ? flight.estDepartureAirport
                  : flight.estArrivalAirport;
              final callsign = flight.callsign.trim().isNotEmpty
                  ? flight.callsign.trim()
                  : flight.icao24;
              final status = _parseStatus(
                null,
              ); // FlightData has no status field
              final timeFormatted = DateFormat('HH:mm').format(time);

              // Find linked ride by flight number
              final linkedRide = rides
                  .where(
                    (r) =>
                        r.flightNumber != null &&
                        r.flightNumber!.toUpperCase() == callsign.toUpperCase(),
                  )
                  .firstOrNull;

              return _buildFlightRow(
                callsign: callsign,
                airport: airport,
                timeFormatted: timeFormatted,
                status: status,
                linkedRide: linkedRide,
                isDark: isDark,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightRow({
    required String callsign,
    required String airport,
    required String timeFormatted,
    required _FlightStatus status,
    required Ride? linkedRide,
    required bool isDark,
  }) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surface;
    final badgeColor = _statusBadgeColor(status);
    final badgeBg = isDark
        ? badgeColor.withValues(alpha: 0.18)
        : _statusBadgeBg(status);

    return Container(
      color: bg,
      child: Column(
        children: [
          Padding(
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
                // Origin / Destination
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
                    timeFormatted,
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
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel(status, null),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
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
                      ? GestureDetector(
                          onTap: () {
                            // Navigate to ride detail if needed
                          },
                          child: Text(
                            '#${linkedRide.id.substring(0, linkedRide.id.length.clamp(0, 8))} · ${linkedRide.clientName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
      ),
    );
  }
}

// ─── Table header cell ────────────────────────────────────────────────────────

class _TableHeaderCell extends StatelessWidget {
  final String label;
  final int flex;

  const _TableHeaderCell(this.label, {required this.flex});

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

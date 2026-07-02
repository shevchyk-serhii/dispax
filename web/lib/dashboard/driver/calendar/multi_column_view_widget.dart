import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../modules/schedule_management/models/calendar_share.dart';
import '../../../modules/schedule_management/services/calendar_share_service.dart';
import '../../../modules/core/navigation_helper.dart';
import 'widgets/ride_calendar_card.dart';

/// Multi-column calendar board: shows drivers' rides side by side for a given
/// day. Each column is headed by the driver's name.
///
/// Layout is responsive: on wide screens (>= [AppDimensions.breakpointDesktop])
/// up to 3 columns share the full width via [Expanded] and a "+N more" indicator
/// is shown when more drivers exist. On narrow screens (phones) every driver is
/// rendered as a fixed-width column inside a horizontal scroll view, so the
/// columns stay wide enough for the compact ride cards to fit.
///
/// Uses a local [FutureBuilder] (not [RideBloc]) so it doesn't interfere with
/// the live-ETA stream. The future is re-fetched when [selectedDay] or [drivers]
/// change via [didUpdateWidget].
class MultiColumnViewWidget extends StatefulWidget {
  final DateTime selectedDay;

  /// The drivers to display as columns (include self if desired). At most 3 are
  /// shown; when more than 3 are passed a "+N more" indicator is shown.
  final List<Person> drivers;

  /// Cross-company calendars shared with the current user (via invite codes).
  /// Each grant becomes an extra read-only column of PII-free shifts and busy
  /// slots, appended after the company drivers' columns.
  final List<CalendarShareGrant> externalShares;

  /// Service used to read the shared calendars; required when
  /// [externalShares] is non-empty.
  final CalendarShareService? shareService;

  /// Called when a ride card is tapped.
  final void Function(Ride) onRideSelected;

  const MultiColumnViewWidget({
    super.key,
    required this.selectedDay,
    required this.drivers,
    required this.onRideSelected,
    this.externalShares = const [],
    this.shareService,
  });

  @override
  State<MultiColumnViewWidget> createState() => _MultiColumnViewWidgetState();
}

class _MultiColumnViewWidgetState extends State<MultiColumnViewWidget> {
  static const int _maxColumns = 3;

  /// Fixed column width used on narrow screens. Keeps each column wide enough
  /// for the compact ride card (time + price) and lets ~2 columns show at once,
  /// with the rest reachable by horizontal scroll.
  static const double _narrowColumnWidth = 200;

  late Future<List<Ride>> _ridesFuture;
  late Future<Map<String, SharedCalendar?>> _sharesFuture;
  late RideService _rideService;

  @override
  void initState() {
    super.initState();
    _rideService = RideService(apiClient: context.read<AuthBloc>().apiClient);
    _ridesFuture = _fetchRides();
    _sharesFuture = _fetchShares();
  }

  @override
  void didUpdateWidget(MultiColumnViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay ||
        oldWidget.drivers != widget.drivers ||
        oldWidget.externalShares != widget.externalShares) {
      setState(() {
        _ridesFuture = _fetchRides();
        _sharesFuture = _fetchShares();
      });
    }
  }

  @override
  void dispose() {
    _rideService.dispose();
    super.dispose();
  }

  Future<List<Ride>> _fetchRides() {
    // Fetch for every driver: on narrow screens all columns are shown (scrolled
    // horizontally), so we must not cap the fetch to the first few.
    final ids = widget.drivers.map((d) => d.id).toList();
    return _rideService.getRidesByDrivers(ids, widget.selectedDay);
  }

  /// Loads every shared calendar for the selected day. A failing share maps to
  /// a null entry so one broken grant only degrades its own column, never the
  /// whole board.
  Future<Map<String, SharedCalendar?>> _fetchShares() async {
    final service = widget.shareService;
    if (service == null || widget.externalShares.isEmpty) return {};
    final entries = await Future.wait(
      widget.externalShares.map((grant) async {
        try {
          final calendar = await service.getSharedCalendar(
            grant.id,
            from: widget.selectedDay,
            to: widget.selectedDay,
          );
          return MapEntry<String, SharedCalendar?>(grant.id, calendar);
        } catch (_) {
          return MapEntry<String, SharedCalendar?>(grant.id, null);
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  void _handlePriceEdited(Ride ride, double newPrice) {
    _rideService
        .setRidePrice(ride.id, newPrice)
        .then((_) {
          if (mounted) {
            setState(() {
              _ridesFuture = _fetchRides();
            });
          }
        })
        .catchError((Object e) {
          if (mounted) {
            NavigationHelper.showSnackBar(
              context,
              'Failed to set price: $e',
              isError: true,
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrow =
        MediaQuery.of(context).size.width < AppDimensions.breakpointDesktop;
    // Narrow screens scroll horizontally and show every column; wide screens
    // cap to [_maxColumns] columns (drivers first, then external shares) that
    // share the full width.
    final visibleDrivers = isNarrow
        ? widget.drivers
        : widget.drivers.take(_maxColumns).toList();
    final externalSlots = isNarrow
        ? widget.externalShares.length
        : (_maxColumns - visibleDrivers.length).clamp(
            0,
            widget.externalShares.length,
          );
    final visibleShares = widget.externalShares.take(externalSlots).toList();
    final extraCount =
        (widget.drivers.length + widget.externalShares.length) -
        (visibleDrivers.length + visibleShares.length);

    return Column(
      children: [
        if (extraCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Showing first 3 drivers — +$extraCount more',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Ride>>(
            future: _ridesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load rides',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                );
              }
              final allRides = snapshot.data ?? [];

              List<Ride> ridesFor(Person driver) =>
                  allRides.where((r) => r.driverId == driver.id).toList()..sort(
                    (a, b) => a.pickupDateTime.compareTo(b.pickupDateTime),
                  );

              _DriverColumn columnFor(Person driver) => _DriverColumn(
                driver: driver,
                rides: ridesFor(driver),
                onRideSelected: widget.onRideSelected,
                onPriceEdited: _handlePriceEdited,
              );

              return FutureBuilder<Map<String, SharedCalendar?>>(
                future: _sharesFuture,
                builder: (context, sharesSnapshot) {
                  final shares =
                      sharesSnapshot.data ?? const <String, SharedCalendar?>{};
                  final sharesLoading =
                      sharesSnapshot.connectionState == ConnectionState.waiting;

                  final columns = <Widget>[
                    ...visibleDrivers.map(columnFor),
                    ...visibleShares.map(
                      (grant) => _ExternalShareColumn(
                        grant: grant,
                        calendar: shares[grant.id],
                        loading: sharesLoading,
                        selectedDay: widget.selectedDay,
                      ),
                    ),
                  ];

                  if (isNarrow) {
                    // Fixed-width columns inside a horizontal scroll view so
                    // each column stays wide enough and overflowing columns are
                    // reachable by scrolling instead of being hidden behind
                    // "+N more".
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: columns
                            .map(
                              (column) => SizedBox(
                                width: _narrowColumnWidth,
                                child: column,
                              ),
                            )
                            .toList(),
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns
                        .map((column) => Expanded(child: column))
                        .toList(),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single driver column in the board view.
class _DriverColumn extends StatelessWidget {
  final Person driver;
  final List<Ride> rides;
  final void Function(Ride) onRideSelected;
  final void Function(Ride, double) onPriceEdited;

  const _DriverColumn({
    required this.driver,
    required this.rides,
    required this.onRideSelected,
    required this.onPriceEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(80),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              driver.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // Rides list or empty state
          Expanded(
            child: rides.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      // The card spans the full column width — the pickup time
                      // is already shown inside the card, so the old left time
                      // rail was redundant (and stealing 36px, which caused the
                      // card content to overflow on the right).
                      return RideCalendarCard(
                        ride: ride,
                        onTap: () => onRideSelected(ride),
                        onPriceEdited: (price) => onPriceEdited(ride, price),
                        showActions: false,
                        compact: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color: colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          const SizedBox(height: 8),
          Text(
            'No rides',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A read-only board column for a cross-company shared calendar: the grantor's
/// shifts and PII-free busy slots for the selected day. Visually marked with a
/// share icon and the grantor's company so it is never mistaken for a company
/// driver; nothing in it is tappable (there are no ride details to open).
class _ExternalShareColumn extends StatelessWidget {
  final CalendarShareGrant grant;
  final SharedCalendar? calendar;
  final bool loading;
  final DateTime selectedDay;

  const _ExternalShareColumn({
    required this.grant,
    required this.calendar,
    required this.loading,
    required this.selectedDay,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Shift times come as "HH:mm[:ss]" strings in the grantor company's local
  /// convention — render the first 5 chars, never convert timezones.
  static String _hhmm(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header — tinted differently from company drivers.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withAlpha(80),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.ios_share, size: 14, color: colorScheme.onSurface),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grant.grantorName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        grant.grantorCompanyName,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final data = calendar;
    if (data == null) {
      // This share failed to load — degrade only this column.
      return Center(
        child: Icon(Icons.cloud_off, size: 32, color: colorScheme.error),
      );
    }

    final shifts = data.shifts
        .where((s) => _sameDay(s.date, selectedDay))
        .toList();
    final slots =
        data.busySlots.where((b) => _sameDay(b.start, selectedDay)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    if (shifts.isEmpty && slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 40,
              color: colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sharedCalendarEmptyDay,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final localizations = MaterialLocalizations.of(context);
    String time(DateTime t) =>
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(t));

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final shift in shifts)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withAlpha(90),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: colorScheme.onSurface),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l10n.sharedCalendarShift} ${_hhmm(shift.startTime)}–${_hhmm(shift.endTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        for (final slot in slots)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  slot.kind == 'Unavailability'
                      ? Icons.do_not_disturb_on_outlined
                      : Icons.local_taxi,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l10n.sharedCalendarBusy} ${time(slot.start)}–${time(slot.end)}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
import '../../ride_management/helpers/flight_status_l10n.dart';
import '../flight_phases.dart';

/// Horizontal step indicator showing how far along a flight is:
/// departure: Geplant → Gestartet → Unterwegs; arrival: Geplant → Unterwegs → Gelandet.
/// Completed steps are green, the current step is amber (red when delayed), future
/// steps are grey. Labels come from the shared `flightStatus*` l10n keys (never
/// hardcoded). Mirrors the visual of [AirportCheckpointProgress] — stateless, no
/// animation; the colour hierarchy alone marks the current step.
///
/// Status that has no position on the linear chain is handled out-of-band:
///  - `cancelled`/`diverted` → the whole bar collapses to a single error label;
///  - `delayed` (or any positive computed delay) → the current step is tinted red
///    and a "+N min" badge is appended; a raw `delayed` status with no known
///    position defaults the active step to "scheduled";
///  - `unknown`/missing/non-airport → nothing is rendered.
class FlightProgressBar extends StatelessWidget {
  static const Color _completed = Color(0xFF4CAF50); // green
  static const Color _current = Color(0xFFFF9800); // amber
  static const Color _pending = Color(0xFF9E9E9E); // grey
  static const Color _delayedColor = Color(0xFFD32F2F); // red

  /// Backend wire status (e.g. "scheduled", "en_route", "landed", "delayed").
  final String? status;
  final bool isArrival;

  /// Positive when the flight is running late (minutes); null/0 hides the badge.
  final int? delayMinutes;

  /// Forces the delayed tint even when [delayMinutes] is unknown (e.g. a raw
  /// "delayed" board status without a computed delta).
  final bool isDelayed;

  /// When true the bar is laid out flat (no Card/title) for dense list rows.
  final bool compact;

  const FlightProgressBar({
    super.key,
    required this.status,
    required this.isArrival,
    this.delayMinutes,
    this.isDelayed = false,
    this.compact = false,
  });

  /// Builds the bar from a [Ride], reusing the ride's flight getters. Returns a
  /// widget that renders nothing when the ride is not an airport transfer.
  factory FlightProgressBar.forRide(Ride ride, {bool compact = false}) {
    final isAirport = ride.isAirportTransfer && ride.flightNumber != null;
    return FlightProgressBar(
      status: isAirport ? ride.flightStatus : null,
      isArrival: ride.isArrival,
      delayMinutes: ride.flightDelayMinutes,
      isDelayed: ride.isFlightDelayed,
      compact: compact,
    );
  }

  /// Whether this bar would render anything at all — lets call sites avoid
  /// emitting surrounding padding/separators for a hidden bar.
  bool get isVisible {
    if (status == null) return false;
    if (FlightPhases.isTerminalOffRamp(status)) return true;
    // A progressing or delayed status is shown; pure "unknown" is not.
    return FlightPhases.phaseOf(status) != null ||
        isDelayed ||
        status!.toLowerCase().trim().contains('delay');
  }

  bool get _delayed => isDelayed || (delayMinutes != null && delayMinutes! > 0);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    if (FlightPhases.isTerminalOffRamp(status)) {
      return _buildOffRamp(context, l10n);
    }

    final chain = FlightPhases.chainFor(isArrival: isArrival);
    // Active step: the chain position of the status, or 0 (scheduled) when the
    // status is delayed/unpositioned.
    final ordinal =
        FlightPhases.phaseOrdinalFor(status, isArrival: isArrival) ?? 0;

    final steps = Row(
      children: [
        for (int i = 0; i < chain.length; i++) ...[
          _buildStep(context, l10n, chain[i], i, ordinal),
          if (i < chain.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < ordinal ? _completed : Colors.grey[300],
              ),
            ),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [steps, if (_delayed) _buildDelayBadge(l10n)],
    );

    if (compact) return content;

    return Card(
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(12.0), child: content),
    );
  }

  Widget _buildOffRamp(BuildContext context, AppLocalizations l10n) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cancel_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          l10n.localizedFlightStatus(status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDelayBadge(AppLocalizations l10n) {
    final minutes = delayMinutes;
    // Only render a "+N min" when we actually know the delta; a bare delayed
    // status still tints the step but has nothing to quantify.
    if (minutes == null || minutes <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        l10n.airportFlightDelay(minutes),
        style: const TextStyle(
          color: _delayedColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    AppLocalizations l10n,
    FlightPhase phase,
    int index,
    int currentOrdinal,
  ) {
    final bool isCompleted = index < currentOrdinal;
    final bool isCurrent = index == currentOrdinal;

    final Color color;
    if (isCompleted) {
      color = _completed;
    } else if (isCurrent) {
      color = _delayed ? _delayedColor : _current;
    } else {
      color = _pending;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            index <= currentOrdinal
                ? Icons.check
                : Icons.radio_button_unchecked,
            size: 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _phaseLabel(l10n, phase),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _phaseLabel(AppLocalizations l10n, FlightPhase phase) {
    switch (phase) {
      case FlightPhase.scheduled:
        return l10n.flightStatusScheduled;
      case FlightPhase.boarding:
        return l10n.flightStatusBoarding;
      case FlightPhase.departed:
        return l10n.flightStatusDeparted;
      case FlightPhase.enRoute:
        return l10n.flightStatusEnRoute;
      case FlightPhase.landed:
        return l10n.flightStatusLanded;
    }
  }
}

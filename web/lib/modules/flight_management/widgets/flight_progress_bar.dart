import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
import '../../ride_management/helpers/flight_status_l10n.dart';
import '../flight_phases.dart';

/// Horizontal step indicator showing how far along a flight is:
/// departure: Geplant → Gestartet → Unterwegs; arrival: Geplant → Unterwegs → Gelandet.
/// Completed steps are green, the current step is amber (red when delayed), future
/// steps are grey. Labels come from the shared `flightStatus*` l10n keys (never
/// hardcoded). Each step circle shows its phase's airplane icon (plane / takeoff /
/// landing) — the colour hierarchy alone marks the current step. The only
/// continuous animation is the en-route pulse: the airplane gliding across the
/// bar blinks (like the ride-status pulse) while the flight is mid-air, and is
/// static when parked before take-off or after landing.
///
/// Status that has no position on the linear chain is handled out-of-band:
///  - `cancelled`/`diverted` → the whole bar collapses to a single error label;
///  - `delayed` (or any positive computed delay) → the current step is tinted red
///    and a "+N min" badge is appended; a raw `delayed` status with no known
///    position defaults the active step to "scheduled";
///  - `unknown`/missing/non-airport → nothing is rendered.
class FlightProgressBar extends StatefulWidget {
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

  /// Origin take-off / (estimated) landing instants for an arrival. When both are
  /// present, an airplane icon crawls across the WHOLE bar at
  /// `(now − departure) / (arrival − departure)` — parked at "Planmäßig" before
  /// take-off and at "Gelandet" after landing. Null on either → no airplane.
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const FlightProgressBar({
    super.key,
    required this.status,
    required this.isArrival,
    this.delayMinutes,
    this.isDelayed = false,
    this.compact = false,
    this.departureTime,
    this.arrivalTime,
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
      departureTime: isAirport ? ride.flightDepartureTime : null,
      arrivalTime: isAirport ? ride.flightTime : null,
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

  @override
  State<FlightProgressBar> createState() => _FlightProgressBarState();
}

class _FlightProgressBarState extends State<FlightProgressBar>
    with SingleTickerProviderStateMixin {
  static const Color _completed = Color(0xFF4CAF50); // green
  static const Color _current = Color(0xFFFF9800); // amber
  static const Color _pending = Color(0xFF9E9E9E); // grey
  static const Color _delayedColor = Color(0xFFD32F2F); // red

  Timer? _ticker;

  /// Blinks the en-route airplane, mirroring the ride-status pulse in
  /// [RideLifecycleStepper] (900 ms, easeInOut). Runs only while the plane is
  /// mid-flight (see [_syncPulse]) so parked planes stay static and widget
  /// tests without a mid-air flight are never kept awake by a repeat().
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      // Full opacity while idle — a parked plane must not look half-faded.
      value: 1.0,
    );
    _pulseAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // A delayed flight is placed on the bar by the wall clock (its airplane and
    // phase highlight both track [flightProgress]); re-read the clock once a
    // minute so "Im Flug"/"Gelandet" light up (and the plane advances) as time
    // passes, without any per-frame animation. Only needed when the time-driven
    // path is active — i.e. a known [departureTime, arrivalTime] window.
    if (widget.departureTime != null && widget.arrivalTime != null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Starts/stops the pulse to match whether the plane is actually mid-air.
  /// Idempotent — called from [build] on every frame the bar recomputes (the
  /// per-minute ticker rebuilds, so the blink self-stops once the flight lands).
  void _syncPulse(bool active) {
    if (active && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!active && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  bool get _delayed =>
      widget.isDelayed ||
      (widget.delayMinutes != null && widget.delayMinutes! > 0);

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final isArrival = widget.isArrival;
    final departureTime = widget.departureTime;
    final arrivalTime = widget.arrivalTime;

    if (!widget.isVisible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    if (FlightPhases.isTerminalOffRamp(status)) {
      return _buildOffRamp(context, l10n);
    }

    final chain = FlightPhases.chainFor(isArrival: isArrival);

    // The single time fraction (0..1) that drives BOTH the airplane's position
    // and — for a delayed flight — the active phase, so they never disagree.
    // Null when the full [departure, arrival] window is unknown.
    final progress = (departureTime != null && arrivalTime != null)
        ? Ride.flightProgress(DateTime.now(), departureTime, arrivalTime)
        : null;

    // Active step: a confirmed MUC status wins; a delayed flight is placed by
    // `progress` (full window) or the landing-time fallback (arrival only), so the
    // highlight tracks the moving airplane instead of freezing on "Planmäßig".
    final landingReached =
        arrivalTime != null && !DateTime.now().isBefore(arrivalTime);
    final ordinal =
        FlightPhases.activeOrdinalFor(
          status,
          isArrival: isArrival,
          landingReached: landingReached,
          progress: progress,
        ) ??
        0;

    // Every cell flexes so the row can never overflow on a narrow card: the step
    // columns shrink their (bounded, wrapping) labels and the connectors take the
    // slack. Steps get the larger flex so the dots/labels stay legible.
    final stepsRow = Row(
      children: [
        for (int i = 0; i < chain.length; i++) ...[
          Expanded(
            flex: 3,
            child: _buildStep(context, l10n, chain[i], i, ordinal),
          ),
          if (i < chain.length - 1)
            Expanded(flex: 2, child: _connector(context, chain, i, ordinal)),
        ],
      ],
    );

    // A single airplane glides across the WHOLE bar by flight time (departure →
    // landing), overlaid on the row of steps. It parks at the left ("Planmäßig")
    // before take-off and at the right ("Gelandet") after landing; in between it
    // follows `progress`. Only shown for an arrival with a known window.
    final showPlane = isArrival && progress != null;
    // The plane blinks only while genuinely mid-air: strictly between the
    // window endpoints and not already confirmed landed by the wire status.
    final blink =
        showPlane &&
        progress > 0 &&
        progress < 1 &&
        FlightPhases.phaseOf(status) != FlightPhase.landed;
    _syncPulse(blink);
    final steps = showPlane
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              // The plane rides on the connector line, so reserve the connector's
              // row height and vertically center the step dots against it.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  // Sit the plane over the connector line (dot is 26 tall; the
                  // line runs through its vertical center at ~13px).
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _BarPlane(
                      fraction: progress,
                      color: _delayed ? _delayedColor : _current,
                      pulse: blink ? _pulseAnimation : null,
                    ),
                  ),
                ),
              ),
              stepsRow,
            ],
          )
        : stepsRow;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [steps, if (_delayed) _buildDelayBadge(l10n)],
    );

    if (widget.compact) return content;

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
          l10n.localizedFlightStatus(widget.status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDelayBadge(AppLocalizations l10n) {
    final minutes = widget.delayMinutes;
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

  /// The line between step [i] and [i+1]. Completed segments (before the current
  /// step) are green; the rest grey. The moving airplane is overlaid across the
  /// whole bar in [build] (not per-connector), so this stays a plain line.
  Widget _connector(
    BuildContext context,
    List<FlightPhase> chain,
    int i,
    int ordinal,
  ) {
    return Container(
      height: 2,
      color: i < ordinal ? _completed : Colors.grey[300],
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

    final icon = Icon(_phaseIcon(phase), size: 15, color: Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          // The en-route plane points right ("in motion" toward landing);
          // every other phase keeps its icon's natural orientation.
          child: phase == FlightPhase.enRoute
              ? RotatedBox(quarterTurns: 1, child: icon)
              : icon,
        ),
        const SizedBox(height: 4),
        Text(
          _phaseLabel(l10n, phase),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// The airplane icon a step circle shows for its phase — replaces the old
  /// check/radio marks; the circle colour alone conveys completed/current/pending.
  IconData _phaseIcon(FlightPhase phase) => switch (phase) {
    FlightPhase.scheduled => Icons.flight, // plain plane, nose up
    FlightPhase.boarding => Icons.airplane_ticket, // departure chain only
    FlightPhase.departed => Icons.flight_takeoff, // departure chain only
    FlightPhase.enRoute => Icons.flight, // rotated to nose-right in _buildStep
    FlightPhase.landed => Icons.flight_land,
  };

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

/// A small airplane at the flight's current [fraction] (0..1) across the WHOLE
/// progress bar. Stateless: the fraction is computed by the parent (which owns
/// the per-minute ticker), and the per-tick jump is smoothed by a one-shot
/// [AnimatedPositioned]. 0 parks it at "Planmäßig", 1 at "Gelandet".
///
/// When [pulse] is non-null the icon blinks with it (the parent passes its
/// repeating pulse only while the flight is mid-air — a repeating animation
/// would hang `pumpAndSettle`, so tests around a mid-air plane must use
/// `pump(duration)` instead). A null [pulse] renders fully opaque.
class _BarPlane extends StatelessWidget {
  static const double _iconSize = 16;

  /// Finds the gliding plane in tests — the step circles now also contain
  /// [Icons.flight], so `find.byIcon` alone no longer identifies it.
  static const Key planeKey = Key('flight-bar-plane');

  /// Flight progress in [0, 1] (the same value that drives the phase highlight).
  final double fraction;
  final Color color;
  final Animation<double>? pulse;

  const _BarPlane({required this.fraction, required this.color, this.pulse});

  Widget _withPulse(Widget child) {
    final pulse = this.pulse;
    if (pulse == null) return child;
    return FadeTransition(opacity: pulse, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = (constraints.maxWidth - _iconSize).clamp(
          0.0,
          double.infinity,
        );
        // The plane traces a shallow arc: climb → cruise → descend, with the
        // nose tilted along the path tangent. Horizontal travel stays in the
        // AnimatedPositioned (so the per-minute nudge glides); the vertical arc
        // and tilt are applied as static Transforms on the icon for this frame.
        final arcOffset = FlightArc.offsetPx(fraction);
        final tilt = FlightArc.tiltRadians(fraction, travel);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: fraction * travel,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, arcOffset), // lift along the arc
                  // Base 90° points the flight icon right (toward "Gelandet");
                  // tilt is added so the nose follows the climb/descent.
                  child: Transform.rotate(
                    angle: 1.5708 + tilt,
                    child: _withPulse(
                      Icon(
                        Icons.flight,
                        key: planeKey,
                        size: _iconSize,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

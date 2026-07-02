/// Pure mapping from a backend flight-status wire string to a position on a
/// linear progress chain, used by [FlightProgressBar]. Kept free of any Flutter
/// imports so it can be unit-tested in isolation (the widget just renders what
/// this decides).
///
/// The chain differs by direction:
///  - departure: Scheduled → Boarding → Departed → EnRoute (we stop at "in the
///    air"; a departing flight landing elsewhere is not our concern).
///  - arrival:   Scheduled → EnRoute → Landed.
///
/// Only the progressing statuses are positions on the chain. `delayed` is
/// orthogonal (a flight can be delayed at any phase — the delay is shown as a
/// badge, not a step), and `cancelled`/`diverted` are terminal off-ramps that
/// replace the whole bar with a single label. Both return `null` from
/// [phaseOrdinalFor]; the caller decides how to render them.
library;

import 'dart:math' as math;

enum FlightPhase { scheduled, boarding, departed, enRoute, landed }

class FlightPhases {
  static const List<FlightPhase> _departureChain = [
    FlightPhase.scheduled,
    FlightPhase.boarding,
    FlightPhase.departed,
    FlightPhase.enRoute,
  ];

  static const List<FlightPhase> _arrivalChain = [
    FlightPhase.scheduled,
    FlightPhase.enRoute,
    FlightPhase.landed,
  ];

  /// The ordered phases shown for a ride of the given direction.
  static List<FlightPhase> chainFor({required bool isArrival}) =>
      isArrival ? _arrivalChain : _departureChain;

  /// Normalizes a raw wire/MUC status to a [FlightPhase], or `null` when the
  /// status has no position on the linear chain (`delayed`, `unknown`,
  /// `cancelled`, `diverted`, or anything unrecognized). Mirrors the matching
  /// rules of `RideFlightStatusL10n.localizedFlightStatus` so labels and the
  /// bar agree.
  static FlightPhase? phaseOf(String? wireStatus) {
    if (wireStatus == null) return null;
    final s = wireStatus.toLowerCase().trim();
    // Order matters: check the more specific tokens first.
    if (s.contains('landed') || s.contains('gelandet')) {
      return FlightPhase.landed;
    }
    if (s.contains('en_route') ||
        s.contains('en route') ||
        s.contains('unterwegs')) {
      return FlightPhase.enRoute;
    }
    if (s.contains('departed') || s.contains('gestartet')) {
      return FlightPhase.departed;
    }
    if (s.contains('boarding') || s.contains('einstieg')) {
      return FlightPhase.boarding;
    }
    if (s.contains('on time') ||
        s.contains('scheduled') ||
        s.contains('planmäßig')) {
      return FlightPhase.scheduled;
    }
    return null;
  }

  /// The index of [wireStatus] within the chain for [isArrival], or `null` when
  /// the status is not a chain position (delayed/unknown/off-ramp) or maps to a
  /// phase that direction does not show (e.g. `landed` on a departure chain).
  ///
  /// On the arrival chain the departure-only phases are projected onto the
  /// nearest arrival position: `departed` (the flight has left its origin →
  /// "in the air, heading to us") becomes `enRoute`, and `boarding` (still on
  /// the ground at origin) becomes `scheduled`. This way an arrival showing the
  /// raw MUC "Gestartet"/"departed" status lights up "Im Flug", not "Planmäßig".
  static int? phaseOrdinalFor(String? wireStatus, {required bool isArrival}) {
    final phase = phaseOf(wireStatus);
    if (phase == null) return null;
    final resolved = isArrival ? _projectOntoArrival(phase) : phase;
    final index = chainFor(isArrival: isArrival).indexOf(resolved);
    return index < 0 ? null : index;
  }

  /// Maps a phase that exists only on the departure chain onto its nearest
  /// position on the arrival chain. Phases already on the arrival chain
  /// (`scheduled`/`enRoute`/`landed`) pass through unchanged.
  static FlightPhase _projectOntoArrival(FlightPhase phase) => switch (phase) {
    FlightPhase.departed => FlightPhase.enRoute, // left origin → heading to us
    FlightPhase.boarding => FlightPhase.scheduled, // still on the ground
    _ => phase,
  };

  /// The chain index the bar should light up as the *active* step.
  ///
  /// A status with a chain position (scheduled/boarding/…/landed) wins outright.
  /// A `delayed` status carries no phase of its own — but a delayed flight is
  /// still somewhere on its journey, so rather than always defaulting to step 0
  /// ("Planmäßig") we place it by time.
  ///
  /// A confirmed MUC status ([phaseOrdinalFor] non-null) always wins outright, so
  /// a flight that lands early still shows "Gelandet", never a time-derived step.
  ///
  /// Only a `delayed` status (no phase of its own) is placed by time, so its bar
  /// tracks the moving airplane instead of freezing on "Planmäßig":
  ///   • [progress] (the SAME `flightProgress(now, departure, arrival)` fraction
  ///     that positions the plane) is used when the full window is known —
  ///     `>= 1` → landed (plane parked at "Gelandet"); `> 0` → enRoute ("Im Flug");
  ///     `0` → scheduled ("Planmäßig"). One input, so phase and plane never drift.
  ///   • otherwise fall back to the arrival-only signal [landingReached]
  ///     (now >= landing time, no take-off time published) → the "in the air" step;
  ///   • else step 0 (scheduled).
  /// Off-ramp/unknown statuses return `null`.
  static int? activeOrdinalFor(
    String? wireStatus, {
    required bool isArrival,
    bool landingReached = false,
    double? progress,
  }) {
    final positioned = phaseOrdinalFor(wireStatus, isArrival: isArrival);
    if (positioned != null) return positioned;
    if (isTerminalOffRamp(wireStatus)) return null;

    final s = wireStatus?.toLowerCase().trim() ?? '';
    final isDelayed = s.contains('delay') || s.contains('verspät');
    if (!isDelayed) return null;

    final chain = chainFor(isArrival: isArrival);
    // The "in the air" step: enRoute for arrivals, the final step otherwise.
    final airborne = isArrival
        ? chain.indexOf(FlightPhase.enRoute)
        : chain.length - 1;
    final airborneStep = airborne < 0 ? 0 : airborne;

    // Full window known → derive the step from the same fraction the plane uses,
    // so the highlight stays in lock-step with the airplane.
    if (progress != null) {
      if (progress >= 1.0) return chain.length - 1; // landed / final step
      if (progress > 0) return airborneStep; // en route / in the air
      return 0; // not yet departed → scheduled
    }

    // Arrival-only fallback (take-off time unknown): the landing time is the only
    // signal — once it has passed the flight is airborne / on final approach.
    if (landingReached) return airborneStep;

    // Delayed but the landing time has not arrived yet → first step.
    return 0;
  }

  /// True for terminal off-ramp statuses (`cancelled`/`diverted`) that abort the
  /// normal chain — the bar renders a single label instead of steps.
  static bool isTerminalOffRamp(String? wireStatus) {
    if (wireStatus == null) return false;
    final s = wireStatus.toLowerCase().trim();
    return s.contains('cancel') ||
        s.contains('gestrichen') ||
        s.contains('divert') ||
        s.contains('umgeleitet');
  }
}

/// Pure geometry for the en-route airplane's flight path along the "Im Flug" →
/// "Gelandet" connector. Instead of sliding flat, the plane traces a shallow
/// parabolic arc — climbing after take-off, cruising at the apex, descending
/// into landing — with its nose tilted to match the path tangent (up on the
/// climb, level at cruise, down on approach).
///
/// Kept Flutter-free and pure so the invariants are unit-tested directly; the
/// widget only multiplies these by pixels and feeds them to Transform.
class FlightArc {
  /// Peak climb height of the arc, in logical pixels. Kept small so the apex
  /// stays within the progress-bar row's vertical headroom (no clipping/overflow).
  static const double arcHeightPx = 8;

  /// Vertical offset of the plane at [fraction] in [0, 1], in logical pixels.
  /// Negative = upward (screen y grows downward). Zero at both endpoints
  /// (take-off and landing sit on the line), peaking at the mid-cruise point.
  ///
  ///   offset(f) = -arcHeightPx · sin(π · f)
  static double offsetPx(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    return -arcHeightPx * math.sin(math.pi * f);
  }

  /// Extra nose tilt (radians) to add on top of the icon's base orientation so
  /// the plane points along the arc's tangent: nose-up just after take-off,
  /// level at the apex, nose-down on approach.
  ///
  /// The path is (x = travel·f, y = offset(f)); the tangent angle is
  /// atan2(dy/df, dx/df). dy/df = -arcHeightPx·π·cos(π·f); dx/df = travel.
  /// [travelPx] is the horizontal span the plane crosses (segment width minus
  /// the icon), so the tilt is proportioned to the on-screen aspect ratio.
  static double tiltRadians(double fraction, double travelPx) {
    final f = fraction.clamp(0.0, 1.0);
    final dy = -arcHeightPx * math.pi * math.cos(math.pi * f);
    final dx = travelPx <= 0 ? 1.0 : travelPx;
    return math.atan2(dy, dx);
  }
}

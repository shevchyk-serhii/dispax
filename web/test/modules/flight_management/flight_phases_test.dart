// Unit tests for FlightPhases — the pure status→chain-position mapper that drives
// FlightProgressBar. Covers both direction chains (departure vs arrival), the
// orthogonal/off-ramp statuses that have no chain position, and the German MUC
// label aliases.

import 'dart:math' as math;

import 'package:dispax/modules/flight_management/flight_phases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightPhases.chainFor', () {
    test('departure chain stops at enRoute (no landed step)', () {
      expect(FlightPhases.chainFor(isArrival: false), [
        FlightPhase.scheduled,
        FlightPhase.boarding,
        FlightPhase.departed,
        FlightPhase.enRoute,
      ]);
    });

    test('arrival chain is scheduled → enRoute → landed', () {
      expect(FlightPhases.chainFor(isArrival: true), [
        FlightPhase.scheduled,
        FlightPhase.enRoute,
        FlightPhase.landed,
      ]);
    });
  });

  group('FlightPhases.phaseOf', () {
    test('maps progressing wire statuses', () {
      expect(FlightPhases.phaseOf('scheduled'), FlightPhase.scheduled);
      expect(FlightPhases.phaseOf('boarding'), FlightPhase.boarding);
      expect(FlightPhases.phaseOf('departed'), FlightPhase.departed);
      expect(FlightPhases.phaseOf('en_route'), FlightPhase.enRoute);
      expect(FlightPhases.phaseOf('landed'), FlightPhase.landed);
    });

    test('maps German MUC aliases', () {
      expect(FlightPhases.phaseOf('Planmäßig'), FlightPhase.scheduled);
      expect(FlightPhases.phaseOf('Gestartet'), FlightPhase.departed);
      expect(FlightPhases.phaseOf('Unterwegs'), FlightPhase.enRoute);
      expect(FlightPhases.phaseOf('Gelandet'), FlightPhase.landed);
    });

    test('non-positional statuses map to null', () {
      expect(FlightPhases.phaseOf('delayed'), isNull);
      expect(FlightPhases.phaseOf('unknown'), isNull);
      expect(FlightPhases.phaseOf('cancelled'), isNull);
      expect(FlightPhases.phaseOf('diverted'), isNull);
      expect(FlightPhases.phaseOf(null), isNull);
      expect(FlightPhases.phaseOf('something-else'), isNull);
    });
  });

  group('FlightPhases.phaseOrdinalFor', () {
    test('departure ordinals follow the departure chain', () {
      expect(FlightPhases.phaseOrdinalFor('scheduled', isArrival: false), 0);
      expect(FlightPhases.phaseOrdinalFor('boarding', isArrival: false), 1);
      expect(FlightPhases.phaseOrdinalFor('departed', isArrival: false), 2);
      expect(FlightPhases.phaseOrdinalFor('en_route', isArrival: false), 3);
    });

    test('arrival ordinals follow the arrival chain', () {
      expect(FlightPhases.phaseOrdinalFor('scheduled', isArrival: true), 0);
      expect(FlightPhases.phaseOrdinalFor('en_route', isArrival: true), 1);
      expect(FlightPhases.phaseOrdinalFor('landed', isArrival: true), 2);
    });

    test('a phase absent from the direction chain returns null', () {
      // landed is not a step on the departure chain
      expect(FlightPhases.phaseOrdinalFor('landed', isArrival: false), isNull);
    });

    test('departure-only phases project onto the arrival chain', () {
      // "departed" (left origin → in the air, heading to us) → enRoute / "Im Flug"
      expect(FlightPhases.phaseOrdinalFor('departed', isArrival: true), 1);
      expect(FlightPhases.phaseOrdinalFor('Gestartet', isArrival: true), 1);
      // "boarding" (still on the ground at origin) → scheduled
      expect(FlightPhases.phaseOrdinalFor('boarding', isArrival: true), 0);
      expect(FlightPhases.phaseOrdinalFor('Einstieg', isArrival: true), 0);
    });

    test('non-positional statuses return null in both directions', () {
      expect(FlightPhases.phaseOrdinalFor('delayed', isArrival: true), isNull);
      expect(FlightPhases.phaseOrdinalFor('unknown', isArrival: false), isNull);
    });
  });

  group('FlightPhases.isTerminalOffRamp', () {
    test('true only for cancelled/diverted (and German aliases)', () {
      expect(FlightPhases.isTerminalOffRamp('cancelled'), isTrue);
      expect(FlightPhases.isTerminalOffRamp('diverted'), isTrue);
      expect(FlightPhases.isTerminalOffRamp('Gestrichen'), isTrue);
      expect(FlightPhases.isTerminalOffRamp('Umgeleitet'), isTrue);
    });

    test('false for progressing/unknown/delayed statuses', () {
      expect(FlightPhases.isTerminalOffRamp('scheduled'), isFalse);
      expect(FlightPhases.isTerminalOffRamp('landed'), isFalse);
      expect(FlightPhases.isTerminalOffRamp('delayed'), isFalse);
      expect(FlightPhases.isTerminalOffRamp('unknown'), isFalse);
      expect(FlightPhases.isTerminalOffRamp(null), isFalse);
    });
  });

  group('FlightArc — en-route arc geometry', () {
    test(
      'offset is zero at take-off and landing, peaks (upward) at mid-cruise',
      () {
        // Endpoints sit on the line: the plane starts/ends on the connector.
        expect(FlightArc.offsetPx(0.0), 0.0);
        expect(FlightArc.offsetPx(1.0), closeTo(0.0, 1e-9));
        // Apex is the most negative (upward) point, equal to the full arc height.
        expect(FlightArc.offsetPx(0.5), closeTo(-FlightArc.arcHeightPx, 1e-9));
        // And it is genuinely above the endpoints throughout the cruise.
        expect(FlightArc.offsetPx(0.25), lessThan(0.0));
        expect(FlightArc.offsetPx(0.75), lessThan(0.0));
      },
    );

    test(
      'offset never exceeds the arc-height budget (stays within headroom)',
      () {
        for (final f in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
          expect(
            FlightArc.offsetPx(f).abs(),
            lessThanOrEqualTo(FlightArc.arcHeightPx + 1e-9),
          );
        }
      },
    );

    test('clamps out-of-range fractions to the segment', () {
      expect(FlightArc.offsetPx(-0.5), 0.0); // before take-off → at start node
      expect(
        FlightArc.offsetPx(1.5),
        closeTo(0.0, 1e-9),
      ); // past landing → at end node
    });

    test('tilt points the nose UP just after take-off and DOWN on approach', () {
      const travel = 100.0;
      // Base icon angle is +90° (points right). Negative tilt rotates the nose
      // up; positive tilt rotates it down.
      expect(FlightArc.tiltRadians(0.1, travel), lessThan(0.0)); // climbing
      expect(
        FlightArc.tiltRadians(0.9, travel),
        greaterThan(0.0),
      ); // descending
    });

    test('tilt is level (zero) at the cruise apex', () {
      expect(FlightArc.tiltRadians(0.5, 100.0), closeTo(0.0, 1e-9));
    });

    test('tilt is anti-symmetric about the apex (climb mirrors descent)', () {
      const travel = 100.0;
      expect(
        FlightArc.tiltRadians(0.2, travel),
        closeTo(-FlightArc.tiltRadians(0.8, travel), 1e-9),
      );
    });

    test(
      'a wider segment flattens the tilt (gentler climb for the same height)',
      () {
        // Same arc height spread over more horizontal travel → shallower tangent.
        final steep = FlightArc.tiltRadians(0.1, 40).abs();
        final gentle = FlightArc.tiltRadians(0.1, 400).abs();
        expect(gentle, lessThan(steep));
        // Sanity: both are real tilts within a quarter turn.
        expect(steep, lessThan(math.pi / 2));
      },
    );
  });

  group('FlightPhases.activeOrdinalFor', () {
    test('a positioned status ignores the time signal and uses its phase', () {
      // en_route on an arrival is ordinal 1 whether or not landing time passed.
      expect(
        FlightPhases.activeOrdinalFor(
          'en_route',
          isArrival: true,
          landingReached: false,
        ),
        1,
      );
      expect(
        FlightPhases.activeOrdinalFor(
          'scheduled',
          isArrival: true,
          landingReached: true,
        ),
        0,
      );
    });

    test('delayed arrival whose landing time has arrived lights up "Im Flug" '
        '(enRoute), not step 0', () {
      // The LH2091 card: Verspätet, landing time reached, but not yet landed.
      // MUC gives delayed arrivals NO take-off time — only the landing time —
      // so this is the real-world signal.
      expect(
        FlightPhases.activeOrdinalFor(
          'delayed',
          isArrival: true,
          landingReached: true,
        ),
        1, // enRoute on the arrival chain
      );
      expect(
        FlightPhases.activeOrdinalFor(
          'Verspätet',
          isArrival: true,
          landingReached: true,
        ),
        1,
      );
    });

    test('delayed arrival before its landing time stays on step 0', () {
      // Before landing time we cannot tell airborne from on-the-ground, so it
      // honestly stays "Planmäßig".
      expect(
        FlightPhases.activeOrdinalFor(
          'delayed',
          isArrival: true,
          landingReached: false,
        ),
        0,
      );
    });

    test(
      'delayed departure past its time lights up the last (enRoute) step',
      () {
        // Departure chain has 4 steps (0..3); airborne → the final one.
        expect(
          FlightPhases.activeOrdinalFor(
            'delayed',
            isArrival: false,
            landingReached: true,
          ),
          3,
        );
      },
    );

    test('off-ramp and unknown return null', () {
      expect(
        FlightPhases.activeOrdinalFor(
          'cancelled',
          isArrival: true,
          landingReached: true,
        ),
        isNull,
      );
      expect(
        FlightPhases.activeOrdinalFor(
          'unknown',
          isArrival: true,
          landingReached: true,
        ),
        isNull,
      );
    });
  });
}

// Unit tests for FlightPhases — the pure status→chain-position mapper that drives
// FlightProgressBar. Covers both direction chains (departure vs arrival), the
// orthogonal/off-ramp statuses that have no chain position, and the German MUC
// label aliases.

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
}

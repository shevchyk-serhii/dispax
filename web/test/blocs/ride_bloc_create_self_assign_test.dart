// Tests for the driver "create ride into the pool, optionally assign to me"
// flow.
//
// Backend behaviour (Approach A): createRide always succeeds and puts the ride
// in the pool. When the driver opts in to "Assign to me", the backend tries to
// self-assign AFTER creating the ride; if that hits a schedule conflict it
// swallows the error and returns the ride still unassigned (the ride is never
// lost). The RideBloc detects "self-assign requested but the created ride came
// back without a driver" and surfaces assignConflict so the UI can offer
// "assign anyway" via the existing override path.
//
// Mirrors ride_bloc_assign_conflict_test.dart.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockRideService mockRideService;

  setUpAll(() {
    registerFallbackValue(TestFixtures.createRideRequest());
  });

  setUp(() {
    mockRideService = MockRideService();
    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  group('RideBloc — driver create-into-pool / assign-to-me', () {
    // ── Pool create (no driverId) → created, no conflict ─────────────────────

    blocTest<RideBloc, RideState>(
      'RideCreateRequested without a driver creates the ride into the pool '
      '(status created, no assignConflict)',
      build: () {
        final pooled = TestFixtures.ride(
          id: 'ride-1',
          status: RideStatus.requested,
        );
        when(
          () => mockRideService.createRide(any()),
        ).thenAnswer((_) async => pooled);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        RideCreateRequested(request: TestFixtures.createRideRequest()),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded (created)', true)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false)
            .having((s) => s.rides.length, 'rides', 1),
      ],
    );

    // ── Self-assign succeeds → created (ride comes back with a driver) ───────

    blocTest<RideBloc, RideState>(
      'RideCreateRequested with self driverId returns a ride assigned to self '
      '→ created, no conflict',
      build: () {
        final assigned = TestFixtures.ride(
          id: 'ride-1',
          driverId: 'driver-1',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.createRide(any()),
        ).thenAnswer((_) async => assigned);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        RideCreateRequested(
          request: TestFixtures.createRideRequest(driverId: 'driver-1'),
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded (created)', true)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false)
            .having((s) => s.rides.first.driverId, 'driverId', 'driver-1'),
      ],
    );

    // ── Self-assign conflict (backend swallowed it) → assignConflict ─────────

    blocTest<RideBloc, RideState>(
      'RideCreateRequested with self driverId but the created ride comes back '
      'unassigned surfaces assignConflict so the UI can offer "assign anyway"',
      build: () {
        // Approach A: ride is created into the pool, self-assign conflicted, so
        // the backend returns it still unassigned (driverId == null).
        final pooled = TestFixtures.ride(
          id: 'ride-1',
          status: RideStatus.requested,
        );
        when(
          () => mockRideService.createRide(any()),
        ).thenAnswer((_) async => pooled);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        RideCreateRequested(
          request: TestFixtures.createRideRequest(driverId: 'driver-1'),
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', true)
            .having((s) => s.conflictRideId, 'conflictRideId', 'ride-1')
            .having((s) => s.conflictDriverId, 'conflictDriverId', 'driver-1')
            .having((s) => s.hasError, 'hasError', false)
            // The ride is still added to the list — it exists in the pool.
            .having((s) => s.rides.length, 'rides', 1),
      ],
    );

    // ── A genuine create failure stays a plain error, not assignConflict ─────

    blocTest<RideBloc, RideState>(
      'RideCreateRequested that throws emits a plain error (not assignConflict)',
      build: () {
        when(
          () => mockRideService.createRide(any()),
        ).thenThrow(ApiException('Invalid client', statusCode: 400));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        RideCreateRequested(
          request: TestFixtures.createRideRequest(driverId: 'driver-1'),
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false),
      ],
    );
  });
}

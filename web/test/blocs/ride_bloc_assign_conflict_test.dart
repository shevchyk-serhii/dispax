// Tests for the new RideAssignRequested → assignConflict path introduced in the
// driver-busy-time-assign-guard feature.
//
// Mirrors the existing reassignConflict tests in ride_bloc_test.dart.

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
  late Ride testRide;

  setUp(() {
    mockRideService = MockRideService();
    testRide = TestFixtures.ride();
    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  group('RideBloc — assign conflict (driver-busy-time-assign-guard)', () {
    // ── 409 without override → assignConflict ────────────────────────────────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested surfaces a 409 as assignConflict (not a bare error) '
      'when overrideScheduleConflict is false',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).thenThrow(
          ApiException(
            'Driver has a Lunch unavailability from 10:00 to 11:00',
            statusCode: 409,
          ),
        );
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: false,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', true)
            .having((s) => s.conflictRideId, 'conflictRideId', 'ride-1')
            .having((s) => s.conflictDriverId, 'conflictDriverId', 'driver-1')
            .having((s) => s.hasError, 'hasError', false),
      ],
    );

    // ── 409 with structured details → conflictInfo carried into the state ────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested carries the backend scheduleConflict details into '
      'the assignConflict state so the dialog can show route + time',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).thenThrow(
          ApiException(
            'Driver already has a ride from A to B at ... overlap',
            statusCode: 409,
            scheduleConflict: const ScheduleConflictInfo(
              rideId: 'other-ride',
              clientId: 'other-client',
              from: 'Maximilianstrasse 10',
              to: 'Munich Airport T2',
              pickupAt: '2026-06-27T07:18:00Z',
            ),
          ),
        );
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: false,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', true)
            .having(
              (s) => s.conflictInfo?.from,
              'conflictInfo.from',
              'Maximilianstrasse 10',
            )
            .having(
              (s) => s.conflictInfo?.to,
              'conflictInfo.to',
              'Munich Airport T2',
            )
            .having(
              (s) => s.conflictInfo?.pickupAt,
              'conflictInfo.pickupAt',
              '2026-06-27T07:18:00Z',
            ),
      ],
    );

    // ── 409 WITH override → plain error (not assignConflict) ─────────────────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested with override=true and 409 emits plain error '
      '(override already requested so no "assign anyway" prompt needed)',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: true,
          ),
        ).thenThrow(ApiException('Some other server error', statusCode: 409));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: true,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false),
      ],
    );

    // ── Successful assign with override ──────────────────────────────────────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested with override=true succeeds and emits loaded with '
      'updated ride when backend returns 200',
      build: () {
        final assigned = testRide.copyWith(
          driverId: 'driver-1',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: true,
          ),
        ).thenAnswer((_) async => assigned);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: true,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having(
              (s) => s.rides.first.status,
              'ride status',
              RideStatus.assigned,
            )
            .having((s) => s.rides.first.driverId, 'ride driverId', 'driver-1'),
      ],
      verify: (_) {
        verify(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: true,
          ),
        ).called(1);
      },
    );

    // ── Non-409 error stays as a plain error ─────────────────────────────────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested with a 400 error emits plain error (not assignConflict)',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).thenThrow(ApiException('Driver not found', statusCode: 400));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(rideId: 'ride-1', driverId: 'driver-1'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false),
      ],
    );

    // ── 409 "already assigned" → alreadyAssigned + reload (stale-state race) ──

    blocTest<RideBloc, RideState>(
      'RideAssignRequested surfaces a 409 "Ride already assigned" as '
      'alreadyAssigned (not assignConflict, not error) and reloads the pending '
      'list so the now-assigned ride drops out',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).thenThrow(
          // Matches the backend body for RideError.RideAlreadyAssigned.
          ApiException('Ride already assigned', statusCode: 409),
        );
        // The ride was taken by someone else, so the refreshed pending list no
        // longer contains it.
        when(
          () => mockRideService.getPendingRides(),
        ).thenAnswer((_) async => <Ride>[]);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: false,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.isAlreadyAssigned, 'isAlreadyAssigned', true)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.hasAssignConflict, 'hasAssignConflict', false)
            .having((s) => s.rides, 'rides reloaded (empty)', isEmpty),
      ],
      verify: (_) {
        verify(() => mockRideService.getPendingRides()).called(1);
      },
    );

    // ── 409 "already assigned" WITH override → still alreadyAssigned ──────────
    // Overriding a schedule conflict cannot un-take a ride; the stale-state
    // branch must win regardless of the override flag.

    blocTest<RideBloc, RideState>(
      'RideAssignRequested with override=true still maps a 409 "already '
      'assigned" to alreadyAssigned (override does not apply to a taken ride)',
      build: () {
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: true,
          ),
        ).thenThrow(ApiException('Ride already assigned', statusCode: 409));
        when(
          () => mockRideService.getPendingRides(),
        ).thenAnswer((_) async => <Ride>[]);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(
          rideId: 'ride-1',
          driverId: 'driver-1',
          overrideScheduleConflict: true,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.isAlreadyAssigned, 'isAlreadyAssigned', true)
            .having((s) => s.hasError, 'hasError', false),
      ],
    );

    // ── overrideScheduleConflict flag is passed to the service ───────────────

    blocTest<RideBloc, RideState>(
      'RideAssignRequested passes overrideScheduleConflict=false to service by default',
      build: () {
        final assigned = testRide.copyWith(
          driverId: 'driver-1',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).thenAnswer((_) async => assigned);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        // No overrideScheduleConflict — defaults to false.
        const RideAssignRequested(rideId: 'ride-1', driverId: 'driver-1'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>().having((s) => s.isLoaded, 'isLoaded', true),
      ],
      verify: (_) {
        verify(
          () => mockRideService.assignDriver(
            'ride-1',
            'driver-1',
            overrideScheduleConflict: false,
          ),
        ).called(1);
      },
    );
  });
}

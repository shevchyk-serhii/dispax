import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class FakePerson extends Fake implements Person {}

void main() {
  late MockRideService mockRideService;
  late Person testUser;
  late Ride testRide;
  late List<Ride> testRides;

  setUpAll(() {
    registerFallbackValue(FakePerson());
    registerFallbackValue(TestFixtures.createRideRequest());
    registerFallbackValue(RideStatus.requested);
  });

  setUp(() {
    mockRideService = MockRideService();
    testUser = TestFixtures.person();
    testRide = TestFixtures.ride();
    testRides = [testRide, TestFixtures.ride(id: 'ride-2')];

    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  group('RideBloc', () {
    test('initial state is RideState.initial()', () {
      final bloc = buildBloc();
      expect(bloc.state, RideState.initial());
      bloc.close();
    });

    blocTest<RideBloc, RideState>(
      'RideLoadRequested emits loading then loaded on first load',
      build: () {
        when(
          () => mockRideService.getRidesForUser(any()),
        ).thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideLoadRequested(user: testUser)),
      expect: () => [RideState.loading(), RideState.loaded(testRides)],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadRequested emits loaded without loading on subsequent loads',
      build: () {
        when(
          () => mockRideService.getRidesForUser(any()),
        ).thenAnswer((_) async => testRides);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(RideLoadRequested(user: testUser)),
      expect: () => [RideState.loaded(testRides)],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadRequested emits error on service failure',
      build: () {
        when(
          () => mockRideService.getRidesForUser(any()),
        ).thenThrow(ApiException('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideLoadRequested(user: testUser)),
      expect: () => [
        RideState.loading(),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideRefreshRequested emits loading then loaded',
      build: () {
        when(
          () => mockRideService.getRidesForUser(any()),
        ).thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideRefreshRequested(user: testUser)),
      expect: () => [RideState.loading(), RideState.loaded(testRides)],
    );

    blocTest<RideBloc, RideState>(
      'RideRefreshRequested emits error on failure',
      build: () {
        when(
          () => mockRideService.getRidesForUser(any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideRefreshRequested(user: testUser)),
      expect: () => [
        RideState.loading(),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideAdded appends ride to list',
      build: buildBloc,
      seed: () => RideState.loaded([testRide]),
      act: (bloc) {
        final newRide = TestFixtures.ride(id: 'ride-new');
        bloc.add(RideAdded(ride: newRide));
      },
      expect: () => [
        isA<RideState>()
            .having((s) => s.rides.length, 'rides.length', 2)
            .having((s) => s.rides.last.id, 'last ride id', 'ride-new'),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideUpdated replaces ride in list',
      build: buildBloc,
      seed: () => RideState.loaded([testRide]),
      act: (bloc) {
        final updated = testRide.copyWith(status: RideStatus.completed);
        bloc.add(RideUpdated(ride: updated));
      },
      expect: () => [
        isA<RideState>().having(
          (s) => s.rides.first.status,
          'updated status',
          RideStatus.completed,
        ),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideCreateRequested emits loading then loaded with new ride',
      build: () {
        final created = TestFixtures.ride(id: 'ride-created');
        when(
          () => mockRideService.createRide(any()),
        ).thenAnswer((_) async => created);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        RideCreateRequested(request: TestFixtures.createRideRequest()),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.rides.length, 'rides.length', 2),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideCreateRequested emits error on failure',
      build: () {
        when(
          () => mockRideService.createRide(any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        RideCreateRequested(request: TestFixtures.createRideRequest()),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideStatusUpdateRequested emits loading then loaded with updated status',
      build: () {
        when(
          () => mockRideService.updateRideStatus(any(), any()),
        ).thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideStatusUpdateRequested(
          rideId: 'ride-1',
          status: RideStatus.completed,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having(
          (s) => s.rides.first.status,
          'updated status',
          RideStatus.completed,
        ),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideStatusUpdateRequested emits error when service returns false',
      build: () {
        when(
          () => mockRideService.updateRideStatus(any(), any()),
        ).thenAnswer((_) async => false);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideStatusUpdateRequested(
          rideId: 'ride-1',
          status: RideStatus.completed,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadPendingRequested emits loading then loaded',
      build: () {
        when(
          () => mockRideService.getPendingRides(),
        ).thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RideLoadPendingRequested()),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        RideState.loaded(testRides),
      ],
    );

    // Regression for the "confirmed ride vanishes from My Rides until manual
    // refresh" bug: a WebSocket RideConfirmed makes the dispatcher dashboard
    // dispatch RideLoadPendingRequested. The shared RideBloc also backs the
    // driver My Rides screen, so loading pending (requested-only) must NOT drop
    // the non-pending rides (assigned/confirmed/...) already held — otherwise a
    // driver-dispatcher's just-confirmed ride disappears.
    blocTest<RideBloc, RideState>(
      'RideLoadPendingRequested keeps existing non-pending rides (merge, not replace)',
      build: () {
        when(
          () => mockRideService.getPendingRides(),
        ).thenAnswer((_) async => <Ride>[]); // no pending rides on the server
        return buildBloc();
      },
      // Seed: one confirmed ride (the driver's own) + one stale requested ride.
      seed: () => RideState.loaded([
        TestFixtures.ride(
          id: 'mine-confirmed',
          driverId: 'me',
          status: RideStatus.confirmed,
        ),
        TestFixtures.ride(id: 'stale-requested', status: RideStatus.requested),
      ]),
      act: (bloc) => bloc.add(const RideLoadPendingRequested()),
      verify: (bloc) {
        // The confirmed ride must survive; the stale requested one is dropped
        // because the fresh pending list is empty.
        expect(
          bloc.state.rides.map((r) => r.id),
          ['mine-confirmed'],
          reason:
              'pending reload must preserve non-pending rides and only refresh '
              'the requested subset',
        );
        expect(bloc.state.rides.single.status, RideStatus.confirmed);
      },
    );

    blocTest<RideBloc, RideState>(
      'RideAssignRequested emits assigning then loaded with updated ride',
      build: () {
        final assigned = testRide.copyWith(
          driverId: 'driver-1',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.assignDriver('ride-1', 'driver-1'),
        ).thenAnswer((_) async => assigned);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(rideId: 'ride-1', driverId: 'driver-1'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.rides.first.status, 'status', RideStatus.assigned),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideAssignRequested emits error on failure',
      build: () {
        when(
          () => mockRideService.assignDriver(any(), any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideAssignRequested(rideId: 'ride-1', driverId: 'driver-1'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideReassignRequested emits assigning then loaded',
      build: () {
        final reassigned = testRide.copyWith(
          driverId: 'driver-2',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.reassignDriver(
            'ride-1',
            'driver-2',
            overrideScheduleConflict: any(named: 'overrideScheduleConflict'),
          ),
        ).thenAnswer((_) async => reassigned);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideReassignRequested(rideId: 'ride-1', newDriverId: 'driver-2'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>().having((s) => s.isLoaded, 'isLoaded', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideReassignRequested emits error on failure',
      build: () {
        when(
          () => mockRideService.reassignDriver(
            any(),
            any(),
            overrideScheduleConflict: any(named: 'overrideScheduleConflict'),
          ),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideReassignRequested(rideId: 'ride-1', newDriverId: 'driver-2'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideReassignRequested surfaces a schedule conflict (409) as '
      'reassignConflict, not a bare error',
      build: () {
        when(
          () => mockRideService.reassignDriver(
            'ride-1',
            'driver-2',
            overrideScheduleConflict: false,
          ),
        ).thenThrow(
          ApiException(
            'Failed to reassign driver: Driver already has a ride',
            statusCode: 409,
          ),
        );
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideReassignRequested(rideId: 'ride-1', newDriverId: 'driver-2'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>()
            .having((s) => s.hasReassignConflict, 'hasReassignConflict', true)
            .having((s) => s.conflictRideId, 'conflictRideId', 'ride-1')
            .having((s) => s.conflictDriverId, 'conflictDriverId', 'driver-2')
            .having((s) => s.hasError, 'hasError', false),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideReassignRequested with override passes the flag and succeeds even '
      'on conflict',
      build: () {
        final reassigned = testRide.copyWith(
          driverId: 'driver-2',
          status: RideStatus.assigned,
        );
        when(
          () => mockRideService.reassignDriver(
            'ride-1',
            'driver-2',
            overrideScheduleConflict: true,
          ),
        ).thenAnswer((_) async => reassigned);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideReassignRequested(
          rideId: 'ride-1',
          newDriverId: 'driver-2',
          overrideScheduleConflict: true,
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isAssigning, 'isAssigning', true),
        isA<RideState>().having((s) => s.isLoaded, 'isLoaded', true),
      ],
      verify: (_) {
        verify(
          () => mockRideService.reassignDriver(
            'ride-1',
            'driver-2',
            overrideScheduleConflict: true,
          ),
        ).called(1);
      },
    );

    // ── RideConfirmRequested ─────────────────────────────────────────────────
    blocTest<RideBloc, RideState>(
      'RideConfirmRequested: calls confirmRide and replaces ride with confirmed status',
      build: () {
        final confirmed = testRide.copyWith(status: RideStatus.confirmed);
        when(
          () => mockRideService.confirmRide('ride-1'),
        ).thenAnswer((_) async => confirmed);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(const RideConfirmRequested(rideId: 'ride-1')),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having(
              (s) => s.rides.first.status,
              'ride status',
              RideStatus.confirmed,
            ),
      ],
      verify: (_) {
        verify(() => mockRideService.confirmRide('ride-1')).called(1);
      },
    );

    blocTest<RideBloc, RideState>(
      'RideConfirmRequested emits error when service throws',
      build: () {
        when(
          () => mockRideService.confirmRide(any()),
        ).thenThrow(ApiException('confirm failed'));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(const RideConfirmRequested(rideId: 'ride-1')),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    // ── RideRejectRequested ──────────────────────────────────────────────────
    blocTest<RideBloc, RideState>(
      'RideRejectRequested: calls rejectRide with reason and replaces ride with requested status',
      build: () {
        final rejected = testRide.copyWith(
          status: RideStatus.requested,
          driverId: null,
        );
        when(
          () => mockRideService.rejectRide('ride-1', 'car breakdown'),
        ).thenAnswer((_) async => rejected);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideRejectRequested(rideId: 'ride-1', reason: 'car breakdown'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having(
              (s) => s.rides.first.status,
              'ride status after reject',
              RideStatus.requested,
            ),
      ],
      verify: (_) {
        verify(
          () => mockRideService.rejectRide('ride-1', 'car breakdown'),
        ).called(1);
      },
    );

    blocTest<RideBloc, RideState>(
      'RideRejectRequested emits error when service throws',
      build: () {
        when(
          () => mockRideService.rejectRide(any(), any()),
        ).thenThrow(ApiException('reject failed'));
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(
        const RideRejectRequested(rideId: 'ride-1', reason: 'breakdown'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    group('RideStatusReceived (task 12: local WS status update)', () {
      blocTest<RideBloc, RideState>(
        'updates matching ride status without HTTP call',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', status: RideStatus.requested),
          TestFixtures.ride(id: 'ride-2', status: RideStatus.requested),
        ]),
        act: (bloc) => bloc.add(
          const RideStatusReceived(
            rideId: 'ride-1',
            newStatus: RideStatus.assigned,
          ),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) => s.rides.firstWhere((r) => r.id == 'ride-1').status,
            'ride-1 status',
            RideStatus.assigned,
          ),
        ],
        verify: (_) {
          // No HTTP calls should be made
          verifyNever(() => mockRideService.getRidesForUser(any()));
          verifyNever(() => mockRideService.updateRideStatus(any(), any()));
        },
      );

      blocTest<RideBloc, RideState>(
        'does not affect other rides',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', status: RideStatus.requested),
          TestFixtures.ride(id: 'ride-2', status: RideStatus.requested),
        ]),
        act: (bloc) => bloc.add(
          const RideStatusReceived(
            rideId: 'ride-1',
            newStatus: RideStatus.inProgress,
          ),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) => s.rides.firstWhere((r) => r.id == 'ride-2').status,
            'ride-2 status unchanged',
            RideStatus.requested,
          ),
        ],
      );

      blocTest<RideBloc, RideState>(
        'no-op when rides list is empty',
        build: buildBloc,
        seed: () => RideState.loaded([]),
        act: (bloc) => bloc.add(
          const RideStatusReceived(
            rideId: 'ride-1',
            newStatus: RideStatus.cancelled,
          ),
        ),
        expect: () => [],
      );

      blocTest<RideBloc, RideState>(
        'unknown rideId emits nothing',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', status: RideStatus.requested),
        ]),
        act: (bloc) => bloc.add(
          const RideStatusReceived(
            rideId: 'unknown-id',
            newStatus: RideStatus.cancelled,
          ),
        ),
        expect: () => [],
      );

      // Regression: onStatusReceived used state.copyWith, which preserved a
      // stale error status (and message) from an earlier failed operation. A
      // live WS update proves the system is healthy, so it must settle to a
      // clean loaded state with the error cleared.
      blocTest<RideBloc, RideState>(
        'clears a stale error status when a WS status update arrives',
        build: buildBloc,
        seed: () =>
            const RideState(
              status: RideStateStatus.error,
              errorMessage: 'Network error',
              rides: [],
            ).copyWith(
              rides: [
                TestFixtures.ride(id: 'ride-1', status: RideStatus.requested),
              ],
            ),
        act: (bloc) => bloc.add(
          const RideStatusReceived(
            rideId: 'ride-1',
            newStatus: RideStatus.assigned,
          ),
        ),
        expect: () => [
          isA<RideState>()
              .having((s) => s.status, 'status', RideStateStatus.loaded)
              .having((s) => s.hasError, 'hasError', false)
              .having((s) => s.errorMessage, 'errorMessage', isNull)
              .having(
                (s) => s.rides.first.status,
                'ride-1 status',
                RideStatus.assigned,
              ),
        ],
      );
    });

    group('RideCheckpointReceived (passenger airport status via WS)', () {
      blocTest<RideBloc, RideState>(
        'updates the matching ride airportCheckpoint without an HTTP call',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', isAirportTransfer: true),
          TestFixtures.ride(id: 'ride-2', isAirportTransfer: true),
        ]),
        act: (bloc) => bloc.add(
          const RideCheckpointReceived(
            rideId: 'ride-1',
            checkpoint: 'terminal_exit',
          ),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) =>
                s.rides.firstWhere((r) => r.id == 'ride-1').airportCheckpoint,
            'ride-1 checkpoint',
            'terminal_exit',
          ),
        ],
        verify: (_) {
          verifyNever(() => mockRideService.getRidesForUser(any()));
        },
      );

      blocTest<RideBloc, RideState>(
        'does not affect other rides',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', isAirportTransfer: true),
          TestFixtures.ride(id: 'ride-2', isAirportTransfer: true),
        ]),
        act: (bloc) => bloc.add(
          const RideCheckpointReceived(rideId: 'ride-1', checkpoint: 'landed'),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) =>
                s.rides.firstWhere((r) => r.id == 'ride-2').airportCheckpoint,
            'ride-2 checkpoint unchanged',
            isNull,
          ),
        ],
      );

      blocTest<RideBloc, RideState>(
        'unknown rideId emits nothing',
        build: buildBloc,
        seed: () => RideState.loaded([TestFixtures.ride(id: 'ride-1')]),
        act: (bloc) => bloc.add(
          const RideCheckpointReceived(rideId: 'unknown', checkpoint: 'landed'),
        ),
        expect: () => [],
      );
    });

    group('RideFlightStatusReceived (live MUC flight board via WS)', () {
      blocTest<RideBloc, RideState>(
        'patches gate/terminal/status of the matching ride without an HTTP call',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(
            id: 'ride-1',
            isAirportTransfer: true,
            gate: 'G12',
            terminal: 'T1',
            flightStatus: 'Scheduled',
          ),
        ]),
        act: (bloc) => bloc.add(
          const RideFlightStatusReceived(
            rideId: 'ride-1',
            gate: 'H18',
            terminal: 'T2',
            flightStatus: 'Landed',
          ),
        ),
        expect: () => [
          isA<RideState>()
              .having(
                (s) => s.rides.firstWhere((r) => r.id == 'ride-1').gate,
                'ride-1 gate',
                'H18',
              )
              .having(
                (s) => s.rides.firstWhere((r) => r.id == 'ride-1').terminal,
                'ride-1 terminal',
                'T2',
              )
              .having(
                (s) => s.rides.firstWhere((r) => r.id == 'ride-1').flightStatus,
                'ride-1 flightStatus',
                'Landed',
              ),
        ],
        verify: (_) {
          verifyNever(() => mockRideService.getRidesForUser(any()));
        },
      );

      blocTest<RideBloc, RideState>(
        'parses estimatedTime into flightTime (local)',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', isAirportTransfer: true),
        ]),
        act: (bloc) => bloc.add(
          const RideFlightStatusReceived(
            rideId: 'ride-1',
            estimatedTime: '2026-07-04T14:30:00Z',
          ),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) => s.rides
                .firstWhere((r) => r.id == 'ride-1')
                .flightTime
                ?.toUtc()
                .toIso8601String(),
            'ride-1 flightTime',
            '2026-07-04T14:30:00.000Z',
          ),
        ],
      );

      blocTest<RideBloc, RideState>(
        'does not affect other rides',
        build: buildBloc,
        seed: () => RideState.loaded([
          TestFixtures.ride(id: 'ride-1', isAirportTransfer: true, gate: 'A1'),
          TestFixtures.ride(id: 'ride-2', isAirportTransfer: true, gate: 'B2'),
        ]),
        act: (bloc) => bloc.add(
          const RideFlightStatusReceived(rideId: 'ride-1', gate: 'Z9'),
        ),
        expect: () => [
          isA<RideState>().having(
            (s) => s.rides.firstWhere((r) => r.id == 'ride-2').gate,
            'ride-2 gate unchanged',
            'B2',
          ),
        ],
      );

      blocTest<RideBloc, RideState>(
        'unknown rideId emits nothing',
        build: buildBloc,
        seed: () => RideState.loaded([TestFixtures.ride(id: 'ride-1')]),
        act: (bloc) => bloc.add(
          const RideFlightStatusReceived(rideId: 'unknown', gate: 'H1'),
        ),
        expect: () => [],
      );
    });

    group('RideAdded deduplication', () {
      // Regression: onRideAdded blindly appended, so a WS RideCreated that
      // raced a getRides() reload produced the same ride twice in the list.
      // (Ride equality is by id, so we assert on the final state's length and
      // contents rather than the emitted-state stream — replacing a same-id
      // ride yields an == list and may not re-emit.)
      blocTest<RideBloc, RideState>(
        'does not duplicate a ride that is already present',
        build: buildBloc,
        seed: () => RideState.loaded([TestFixtures.ride(id: 'ride-1')]),
        act: (bloc) =>
            bloc.add(RideAdded(ride: TestFixtures.ride(id: 'ride-1'))),
        verify: (bloc) {
          expect(bloc.state.rides.length, 1);
          expect(bloc.state.rides.single.id, 'ride-1');
        },
      );

      blocTest<RideBloc, RideState>(
        'still appends a genuinely new ride',
        build: buildBloc,
        seed: () => RideState.loaded([TestFixtures.ride(id: 'ride-1')]),
        act: (bloc) =>
            bloc.add(RideAdded(ride: TestFixtures.ride(id: 'ride-2'))),
        verify: (bloc) {
          expect(bloc.state.rides.length, 2);
          expect(bloc.state.rides.map((r) => r.id), ['ride-1', 'ride-2']);
        },
      );
    });
  });
}

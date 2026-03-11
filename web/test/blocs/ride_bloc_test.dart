import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktopus/blocs/ride/ride_bloc.dart';
import 'package:oktopus/blocs/ride/ride_event.dart';
import 'package:oktopus/blocs/ride/ride_state.dart';
import 'package:oktopus/modules/core/models/person.dart';
import 'package:oktopus/modules/core/services/api_client.dart';
import 'package:oktopus/modules/ride_management/models/ride.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class FakePerson extends Fake implements Person {}

class FakeCreateRideRequest extends Fake
    implements
        // ignore: undefined_class
        dynamic {}

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
        when(() => mockRideService.getRidesForUser(any()))
            .thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideLoadRequested(user: testUser)),
      expect: () => [
        RideState.loading(),
        RideState.loaded(testRides),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadRequested emits loaded without loading on subsequent loads',
      build: () {
        when(() => mockRideService.getRidesForUser(any()))
            .thenAnswer((_) async => testRides);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(RideLoadRequested(user: testUser)),
      expect: () => [
        RideState.loaded(testRides),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadRequested emits error on service failure',
      build: () {
        when(() => mockRideService.getRidesForUser(any()))
            .thenThrow(ApiException('Network error'));
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
        when(() => mockRideService.getRidesForUser(any()))
            .thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideRefreshRequested(user: testUser)),
      expect: () => [
        RideState.loading(),
        RideState.loaded(testRides),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideRefreshRequested emits error on failure',
      build: () {
        when(() => mockRideService.getRidesForUser(any()))
            .thenThrow(ApiException('fail'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(RideRefreshRequested(user: testUser)),
      expect: () => [
        RideState.loading(),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideDeleteRequested emits deleting then loaded with ride removed',
      build: () {
        when(() => mockRideService.deleteRide('ride-1'))
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(const RideDeleteRequested(rideId: 'ride-1')),
      expect: () => [
        isA<RideState>().having((s) => s.isDeleting, 'isDeleting', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.rides.length, 'rides.length', 1)
            .having((s) => s.rides.first.id, 'first ride id', 'ride-2'),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideDeleteRequested emits error when service returns false',
      build: () {
        when(() => mockRideService.deleteRide('ride-1'))
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(const RideDeleteRequested(rideId: 'ride-1')),
      expect: () => [
        isA<RideState>().having((s) => s.isDeleting, 'isDeleting', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideDeleteRequested emits error on exception',
      build: () {
        when(() => mockRideService.deleteRide('ride-1'))
            .thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(const RideDeleteRequested(rideId: 'ride-1')),
      expect: () => [
        isA<RideState>().having((s) => s.isDeleting, 'isDeleting', true),
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
        when(() => mockRideService.createRide(any()))
            .thenAnswer((_) async => created);
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
        when(() => mockRideService.createRide(any()))
            .thenThrow(ApiException('fail'));
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
        when(() => mockRideService.updateRideStatus(any(), any()))
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(const RideStatusUpdateRequested(
        rideId: 'ride-1',
        status: RideStatus.completed,
      )),
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
        when(() => mockRideService.updateRideStatus(any(), any()))
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      seed: () => RideState.loaded([testRide]),
      act: (bloc) => bloc.add(const RideStatusUpdateRequested(
        rideId: 'ride-1',
        status: RideStatus.completed,
      )),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideLoadPendingRequested emits loading then loaded',
      build: () {
        when(() => mockRideService.getPendingRides())
            .thenAnswer((_) async => testRides);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RideLoadPendingRequested()),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        RideState.loaded(testRides),
      ],
    );

    blocTest<RideBloc, RideState>(
      'RideAssignRequested emits assigning then loaded with updated ride',
      build: () {
        final assigned =
            testRide.copyWith(driverId: 'driver-1', status: RideStatus.assigned);
        when(() => mockRideService.assignDriver('ride-1', 'driver-1'))
            .thenAnswer((_) async => assigned);
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
        when(() => mockRideService.assignDriver(any(), any()))
            .thenThrow(ApiException('fail'));
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
        final reassigned =
            testRide.copyWith(driverId: 'driver-2', status: RideStatus.assigned);
        when(() => mockRideService.reassignDriver('ride-1', 'driver-2'))
            .thenAnswer((_) async => reassigned);
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
        when(() => mockRideService.reassignDriver(any(), any()))
            .thenThrow(ApiException('fail'));
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
  });
}

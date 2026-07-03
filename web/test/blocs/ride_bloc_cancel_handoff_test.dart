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
  late List<Ride> testRides;

  setUp(() {
    mockRideService = MockRideService();
    testRide = TestFixtures.ride();
    testRides = [testRide];
    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  // ── RideCancelRequested ──────────────────────────────────────────────────

  group('RideCancelRequested', () {
    blocTest<RideBloc, RideState>(
      'emits cancelling then loaded (ride removed) on success',
      build: () {
        when(
          () => mockRideService.cancelRide('ride-1', 'driver_unavailable'),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideCancelRequested(
          rideId: 'ride-1',
          reason: 'driver_unavailable',
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isCancelling, 'isCancelling', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.rides, 'rides', isEmpty),
      ],
      verify: (_) {
        verify(
          () => mockRideService.cancelRide('ride-1', 'driver_unavailable'),
        ).called(1);
      },
    );

    blocTest<RideBloc, RideState>(
      'emits cancelling then error on ApiException',
      build: () {
        when(() => mockRideService.cancelRide(any(), any())).thenThrow(
          ApiException('Unknown cancellation reason', statusCode: 400),
        );
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideCancelRequested(rideId: 'ride-1', reason: 'bad_reason'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isCancelling, 'isCancelling', true),
        isA<RideState>()
            .having((s) => s.hasError, 'hasError', true)
            // Regression: the ApiException branch used to drop the typed
            // cause (only the generic branch set `error: e`), so friendlyError
            // could not classify the failure.
            .having((s) => s.error, 'error', isA<ApiException>()),
      ],
    );

    blocTest<RideBloc, RideState>(
      'emits cancelling then error on generic exception',
      build: () {
        when(
          () => mockRideService.cancelRide(any(), any()),
        ).thenThrow(Exception('network'));
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideCancelRequested(rideId: 'ride-1', reason: 'other'),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isCancelling, 'isCancelling', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );
  });

  // ── RideHandOffRequested ─────────────────────────────────────────────────

  group('RideHandOffRequested', () {
    blocTest<RideBloc, RideState>(
      'emits handingOff then loaded with updated ride on success',
      build: () {
        final handedOff = testRide.copyWith(status: RideStatus.handedOff);
        when(
          () => mockRideService.handOffRide(
            'ride-1',
            externalDriverId: 'ext-driver-1',
            partnerCompanyId: 'partner-1',
          ),
        ).thenAnswer((_) async => handedOff);
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideHandOffRequested(
          rideId: 'ride-1',
          externalDriverId: 'ext-driver-1',
          partnerCompanyId: 'partner-1',
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isHandingOff, 'isHandingOff', true),
        isA<RideState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having(
              (s) => s.rides.first.status,
              'updated status',
              RideStatus.handedOff,
            ),
      ],
      verify: (_) {
        verify(
          () => mockRideService.handOffRide(
            'ride-1',
            externalDriverId: 'ext-driver-1',
            partnerCompanyId: 'partner-1',
          ),
        ).called(1);
      },
    );

    blocTest<RideBloc, RideState>(
      'emits handingOff then error on ApiException (409 already assigned)',
      build: () {
        when(
          () => mockRideService.handOffRide(
            any(),
            externalDriverId: any(named: 'externalDriverId'),
            partnerCompanyId: any(named: 'partnerCompanyId'),
          ),
        ).thenThrow(ApiException('Ride already assigned', statusCode: 409));
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideHandOffRequested(
          rideId: 'ride-1',
          externalDriverId: 'ext-driver-1',
          partnerCompanyId: 'partner-1',
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isHandingOff, 'isHandingOff', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<RideBloc, RideState>(
      'emits handingOff then error on generic exception',
      build: () {
        when(
          () => mockRideService.handOffRide(
            any(),
            externalDriverId: any(named: 'externalDriverId'),
            partnerCompanyId: any(named: 'partnerCompanyId'),
          ),
        ).thenThrow(Exception('network'));
        return buildBloc();
      },
      seed: () => RideState.loaded(testRides),
      act: (bloc) => bloc.add(
        const RideHandOffRequested(
          rideId: 'ride-1',
          externalDriverId: 'ext-driver-1',
          partnerCompanyId: 'partner-1',
        ),
      ),
      expect: () => [
        isA<RideState>().having((s) => s.isHandingOff, 'isHandingOff', true),
        isA<RideState>().having((s) => s.hasError, 'hasError', true),
      ],
    );
  });
}

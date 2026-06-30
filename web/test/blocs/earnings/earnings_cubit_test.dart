import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/earnings/earnings_cubit.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/driver_earnings.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';

class MockRideService extends Mock implements RideService {}

DriverEarnings _earnings() => const DriverEarnings(
  period: 'week',
  grossRevenue: 120.0,
  totalExpenses: 20.0,
  netRevenue: 100.0,
  completedRides: 4,
  cancelledRides: 1,
  avgFare: 30.0,
  currency: 'EUR',
  buckets: [],
);

void main() {
  late MockRideService mockService;

  setUp(() {
    mockService = MockRideService();
    registerFallbackValue(DateTime(2026));
  });

  EarningsCubit buildCubit() => EarningsCubit(rideService: mockService);

  group('EarningsCubit', () {
    test('initial state is EarningsState.initial()', () {
      final cubit = buildCubit();
      expect(cubit.state.status, EarningsStatus.initial);
      expect(cubit.state.period, EarningsPeriod.week);
      cubit.close();
    });

    blocTest<EarningsCubit, EarningsState>(
      'load() uses the injected RideService and emits loading then loaded',
      build: () {
        when(
          () => mockService.getDriverEarnings(any(), any(), any()),
        ).thenAnswer((_) async => _earnings());
        return buildCubit();
      },
      act: (cubit) => cubit.load('driver-1'),
      expect: () => [
        isA<EarningsState>().having(
          (s) => s.status,
          'status',
          EarningsStatus.loading,
        ),
        isA<EarningsState>()
            .having((s) => s.status, 'status', EarningsStatus.loaded)
            .having((s) => s.data?.grossRevenue, 'grossRevenue', 120.0),
      ],
      verify: (_) {
        // Regression: the cubit must call the injected (authorized) service
        // with the driver id and current period — never construct its own
        // unauthenticated RideService/ApiClient.
        verify(
          () => mockService.getDriverEarnings('driver-1', 'week', any()),
        ).called(1);
      },
    );

    blocTest<EarningsCubit, EarningsState>(
      'load() emits error when the service throws a generic error',
      build: () {
        when(
          () => mockService.getDriverEarnings(any(), any(), any()),
        ).thenThrow(ApiException('boom'));
        return buildCubit();
      },
      act: (cubit) => cubit.load('driver-1'),
      expect: () => [
        isA<EarningsState>().having(
          (s) => s.status,
          'status',
          EarningsStatus.loading,
        ),
        isA<EarningsState>()
            .having((s) => s.status, 'status', EarningsStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Failed to load'),
            )
            // The typed cause is carried so the UI can map it via friendlyError.
            .having((s) => s.error, 'error', isA<ApiException>()),
      ],
    );

    blocTest<EarningsCubit, EarningsState>(
      'load() does NOT emit a dead-end error on 401 — the forced logout '
      'handles routing to the login screen instead',
      build: () {
        when(
          () => mockService.getDriverEarnings(any(), any(), any()),
        ).thenThrow(UnauthorizedException());
        return buildCubit();
      },
      act: (cubit) => cubit.load('driver-1'),
      // Only the loading state — no EarningsStatus.error. Rendering "Failed to
      // load earnings" with a useless "Try again" on top of a logout is the bug.
      expect: () => [
        isA<EarningsState>().having(
          (s) => s.status,
          'status',
          EarningsStatus.loading,
        ),
      ],
    );
  });
}

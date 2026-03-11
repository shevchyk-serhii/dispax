import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/blocs/ride/ride_state.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('RideState', () {
    test('initial() has correct defaults', () {
      final state = RideState.initial();
      expect(state.status, RideStateStatus.initial);
      expect(state.rides, isEmpty);
      expect(state.errorMessage, isNull);
      expect(state.deletingRideId, isNull);
    });

    test('loading() has loading status', () {
      final state = RideState.loading();
      expect(state.status, RideStateStatus.loading);
      expect(state.rides, isEmpty);
    });

    test('loaded() has loaded status and rides', () {
      final rides = [TestFixtures.ride()];
      final state = RideState.loaded(rides);
      expect(state.status, RideStateStatus.loaded);
      expect(state.rides, rides);
    });

    test('error() has error status and message', () {
      final state = RideState.error('Something went wrong');
      expect(state.status, RideStateStatus.error);
      expect(state.errorMessage, 'Something went wrong');
    });

    test('copyWith preserves fields when not overridden', () {
      final rides = [TestFixtures.ride()];
      final original = RideState.loaded(rides);
      final copied = original.copyWith(errorMessage: 'err');

      expect(copied.status, RideStateStatus.loaded);
      expect(copied.rides, rides);
      expect(copied.errorMessage, 'err');
    });

    test('copyWith overrides specified fields', () {
      final state = RideState.initial();
      final copied = state.copyWith(
        status: RideStateStatus.loading,
        deletingRideId: 'ride-1',
      );

      expect(copied.status, RideStateStatus.loading);
      expect(copied.deletingRideId, 'ride-1');
    });

    test('isLoading getter', () {
      expect(RideState.loading().isLoading, isTrue);
      expect(RideState.loaded([]).isLoading, isFalse);
    });

    test('isLoaded getter', () {
      expect(RideState.loaded([]).isLoaded, isTrue);
      expect(RideState.loading().isLoaded, isFalse);
    });

    test('hasError getter', () {
      expect(RideState.error('e').hasError, isTrue);
      expect(RideState.loaded([]).hasError, isFalse);
    });

    test('isEmpty returns true when loaded with no rides', () {
      expect(RideState.loaded([]).isEmpty, isTrue);
    });

    test('isEmpty returns false when loaded with rides', () {
      expect(RideState.loaded([TestFixtures.ride()]).isEmpty, isFalse);
    });

    test('isEmpty returns false when not loaded', () {
      expect(RideState.loading().isEmpty, isFalse);
    });

    test('isDeleting getter', () {
      final state = const RideState(status: RideStateStatus.deleting);
      expect(state.isDeleting, isTrue);
      expect(RideState.loaded([]).isDeleting, isFalse);
    });

    test('isAssigning getter', () {
      final state = const RideState(status: RideStateStatus.assigning);
      expect(state.isAssigning, isTrue);
      expect(RideState.loaded([]).isAssigning, isFalse);
    });

    test('Equatable props include all fields', () {
      final a = RideState.loaded([TestFixtures.ride()]);
      final b = RideState.loaded([TestFixtures.ride()]);
      expect(a, b);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
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

    // Regression: copyWith must KEEP the existing errorMessage when the caller
    // does not pass one. Before the fix, `errorMessage: errorMessage` (no
    // `?? this.errorMessage`) silently nulled it out, producing a state with
    // `status == error` but `errorMessage == null` — which crashed
    // TodayRidesScreen at `rideState.errorMessage!` (the "Null check operator
    // used on a null value" red screen on the empty "Today" tab).
    test('copyWith preserves errorMessage when not overridden', () {
      final original = RideState.error('Failed to load rides');
      final copied = original.copyWith(rides: const []);

      expect(copied.status, RideStateStatus.error);
      expect(
        copied.errorMessage,
        'Failed to load rides',
        reason:
            'copyWith must not drop the existing errorMessage — an error '
            'state with a null message crashes TodayRidesScreen (errorMessage!)',
      );
    });

    // The exact end-to-end shape of the crash: an error state whose rides
    // belong to OTHER drivers gets scoped down to the current driver's rides
    // (here: none) via copyWith inside `_scopeToMyRides`. The scoped state must
    // still carry its error message so the error UI can render it safely.
    test(
      'scoping an error state to a driver with no rides keeps the message',
      () {
        final otherDriversRides = [
          TestFixtures.ride(id: 'r-1', driverId: 'someone-else'),
        ];
        final errorState = RideState.error(
          'Failed to load rides',
        ).copyWith(rides: otherDriversRides);

        // Mirror _scopeToMyRides: narrow rides to the current driver ("me").
        final scoped = errorState.copyWith(
          rides: errorState.rides.where((r) => r.driverId == 'me').toList(),
        );

        expect(scoped.hasError, isTrue);
        expect(scoped.rides, isEmpty);
        expect(
          scoped.errorMessage,
          isNotNull,
          reason:
              'After scoping out other drivers, the error message must survive '
              'so `rideState.errorMessage!` in buildBody does not throw',
        );
      },
    );

    // The flip side of the fix: callers that DO want to clear the message
    // (e.g. `copyWith(status: loading, errorMessage: null)` when a new load
    // starts) must still be able to. The sentinel must treat an explicit null
    // as "clear", not "leave as is".
    test('copyWith clears errorMessage when null is passed explicitly', () {
      final original = RideState.error('stale error');
      final copied = original.copyWith(
        status: RideStateStatus.loading,
        errorMessage: null,
      );

      expect(copied.status, RideStateStatus.loading);
      expect(
        copied.errorMessage,
        isNull,
        reason:
            'An explicit errorMessage: null must clear the message so a fresh '
            'load does not carry a stale error',
      );
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

    // Regression: a conflict state carries conflictRideId/conflictDriverId so the
    // UI can offer "assign anyway". A WebSocket status update arriving while the
    // conflict dialog is open calls `copyWith(rides: ...)` WITHOUT the conflict
    // fields. Before the sentinel fix, those omitted fields were nulled out,
    // flipping `hasAssignConflict` to false and breaking the override dialog
    // mid-flow. copyWith must KEEP the conflict fields when not overridden.
    test('copyWith preserves conflict fields when not overridden', () {
      const original = RideState(
        status: RideStateStatus.assignConflict,
        conflictRideId: 'ride-A',
        conflictDriverId: 'driver-X',
      );

      // Mirror onStatusReceived: a WebSocket update refreshes only `rides`.
      final copied = original.copyWith(rides: [TestFixtures.ride()]);

      expect(copied.conflictRideId, 'ride-A');
      expect(copied.conflictDriverId, 'driver-X');
      expect(
        copied.hasAssignConflict,
        isTrue,
        reason:
            'A WebSocket status update must not drop the conflict fields, or '
            'the open "assign anyway" dialog loses its target ride/driver.',
      );
    });

    // The flip side: callers that DO want to clear the conflict fields (e.g.
    // returning to a clean loaded state) must still be able to via explicit null.
    test('copyWith clears conflict fields when null is passed explicitly', () {
      const original = RideState(
        status: RideStateStatus.assignConflict,
        conflictRideId: 'ride-A',
        conflictDriverId: 'driver-X',
      );

      final copied = original.copyWith(
        status: RideStateStatus.loaded,
        conflictRideId: null,
        conflictDriverId: null,
      );

      expect(copied.conflictRideId, isNull);
      expect(copied.conflictDriverId, isNull);
      expect(copied.hasAssignConflict, isFalse);
    });

    // deletingRideId is nullable too and must survive an unrelated copyWith.
    test('copyWith preserves deletingRideId when not overridden', () {
      const original = RideState(
        status: RideStateStatus.deleting,
        deletingRideId: 'ride-9',
      );

      final copied = original.copyWith(rides: [TestFixtures.ride()]);

      expect(
        copied.deletingRideId,
        'ride-9',
        reason: 'An unrelated copyWith must not drop deletingRideId',
      );
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

    // Regression: after a dispatcher sets a ride's price, the RideBloc reloads
    // and emits RideState.loaded with a list whose ONLY difference is that
    // ride's price. If price is absent from Ride.==, the two lists compare
    // equal, this Equatable RideState compares equal, the emit is suppressed
    // and the day-view card keeps showing "Set price". The states MUST differ.
    test('a price-only change in a ride yields a different RideState', () {
      final before = RideState.loaded([TestFixtures.ride(price: null)]);
      final after = RideState.loaded([TestFixtures.ride(price: 100.0)]);
      expect(after, isNot(before));
    });
  });
}

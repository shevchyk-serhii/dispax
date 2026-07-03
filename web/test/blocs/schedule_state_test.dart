import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/schedule/schedule_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';

void main() {
  group('ScheduleState.copyWith', () {
    // Regression: copyWith must KEEP the existing errorMessage/error when the
    // caller does not pass them. Before the fix, `errorMessage: errorMessage`
    // (no sentinel) silently nulled them, so an unrelated copyWith on an error
    // state lost the error text. Same pattern as RideState.
    test('preserves errorMessage and error when not overridden', () {
      final cause = ApiException('boom', statusCode: 500);
      final original = ScheduleState.error(
        'Failed to load schedule',
        cause: cause,
      );
      final copied = original.copyWith(lastDriverId: 'driver-1');

      expect(copied.status, ScheduleStateStatus.error);
      expect(
        copied.errorMessage,
        'Failed to load schedule',
        reason: 'copyWith must not drop the existing errorMessage',
      );
      expect(
        copied.error,
        same(cause),
        reason: 'copyWith must not drop the typed cause used by friendlyError',
      );
    });

    // The flip side: explicit null must still clear (fresh load transitions).
    test('clears errorMessage and error when null is passed explicitly', () {
      final original = ScheduleState.error(
        'stale',
        cause: ApiException('boom', statusCode: 503),
      );
      final copied = original.copyWith(
        status: ScheduleStateStatus.loading,
        errorMessage: null,
        error: null,
      );

      expect(copied.status, ScheduleStateStatus.loading);
      expect(copied.errorMessage, isNull);
      expect(copied.error, isNull);
    });

    test('overrides errorMessage when a new value is passed', () {
      final original = ScheduleState.error('old');
      expect(original.copyWith(errorMessage: 'new').errorMessage, 'new');
    });
  });
}

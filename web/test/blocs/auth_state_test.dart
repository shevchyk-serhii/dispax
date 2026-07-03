import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';

void main() {
  group('AuthState.copyWith', () {
    // Regression: copyWith must KEEP the existing errorMessage when the caller
    // does not pass one. Before the fix, `errorMessage: errorMessage` (no
    // sentinel) silently nulled it out, producing a state with
    // `status == error` but `errorMessage == null` — the login card then
    // rendered an empty error banner (and any `errorMessage!` consumer would
    // crash). Same pattern as RideState (see ride_state_test.dart).
    test('preserves errorMessage when not overridden', () {
      final original = AuthState.error('Invalid credentials');
      final copied = original.copyWith(biometricAvailable: true);

      expect(copied.status, AuthStatus.error);
      expect(
        copied.errorMessage,
        'Invalid credentials',
        reason:
            'copyWith must not drop the existing errorMessage — an error '
            'state with a null message renders an empty login error banner',
      );
    });

    test('preserves typed error cause when not overridden', () {
      final cause = ApiException('boom', statusCode: 503);
      final original = AuthState.error('Network error', cause: cause);
      final copied = original.copyWith(biometricAvailable: true);

      expect(
        copied.error,
        same(cause),
        reason:
            'copyWith must not drop the typed cause — the login card uses it '
            'to map network failures through friendlyError',
      );
    });

    // The flip side: callers that DO want to clear (e.g. AuthErrorCleared →
    // `copyWith(status: unauthenticated, errorMessage: null)`) must still be
    // able to. The sentinel must treat an explicit null as "clear".
    test('clears errorMessage and error when null is passed explicitly', () {
      final original = AuthState.error(
        'stale error',
        cause: ApiException('boom', statusCode: 503),
      );
      final copied = original.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
        error: null,
      );

      expect(copied.status, AuthStatus.unauthenticated);
      expect(copied.errorMessage, isNull);
      expect(copied.error, isNull);
    });

    test('overrides errorMessage when a new value is passed', () {
      final original = AuthState.error('old');
      final copied = original.copyWith(errorMessage: 'new');

      expect(copied.errorMessage, 'new');
    });
  });
}

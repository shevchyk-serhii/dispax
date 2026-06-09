@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Negative create-ride validation: the backend must reject invalid requests
/// AND not create a ride. These guard the validation layer
/// (ride/validation/RideValidators.scala + RideService.createRide).
void main() {
  late String clientToken;

  setUp(() async {
    await resetTestData();
    clientToken = await apiLogin(kDevClient1, kDevPassword);
  });

  test('rejects a ride whose pickup and dropoff addresses are identical',
      () async {
    final res = await createRide(clientToken,
        from: 'Marienplatz, München', to: 'Marienplatz, München');
    expect(res.status, 400,
        reason: 'identical from/to must be a 400, was ${res.status}');
    expect(res.error, contains('different'),
        reason: 'error should explain addresses must differ: ${res.error}');
  });

  test('rejects a ride with a pickup time well in the past', () async {
    final res = await createRide(clientToken,
        pickupDateTime: pickupAt(const Duration(minutes: -10)));
    expect(res.status, 400,
        reason: 'a 10-min-past pickup must be rejected, was ${res.status}');
    expect(res.error?.toLowerCase(), contains('past'),
        reason: 'error should mention the past: ${res.error}');
  });

  test('accepts a ride scheduled in the future', () async {
    final res = await createRide(clientToken,
        pickupDateTime: pickupAt(const Duration(hours: 1)));
    expect(res.status, anyOf(200, 201),
        reason: 'a future pickup should succeed, was ${res.status}');
  });

  test('accepts a pickup within the clock-skew tolerance (2 min past)',
      () async {
    // RidePolicy.ClockSkewToleranceSeconds = 300s, so a 2-min-past pickup is
    // still valid (a client whose clock runs fast must not be rejected).
    // The DTO validator and RideService must agree on this tolerance.
    final res = await createRide(clientToken,
        pickupDateTime: pickupAt(const Duration(minutes: -2)));
    expect(res.status, anyOf(200, 201),
        reason: 'a 2-min-past pickup is within tolerance, was ${res.status}: '
            '${res.error}');
  });
}

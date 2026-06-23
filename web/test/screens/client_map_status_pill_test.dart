import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/client_map_screen.dart';

void main() {
  group('ClientMapScreen.clientStatusLabel', () {
    // Regression guard: before the fix, assigned always returned "Driver on
    // the way" regardless of driverEnRoute. This test documents the correct
    // post-fix mapping and will catch any reversion.
    group('assigned status gated on driverEnRoute', () {
      test(
        'assigned + driverEnRoute false => "Driver assigned" (not "Driver on the way")',
        () {
          expect(
            ClientMapScreen.clientStatusLabel(
              RideStatus.assigned,
              driverEnRoute: false,
            ),
            'Driver assigned',
          );
        },
      );

      test('assigned + driverEnRoute true => "Driver on the way"', () {
        expect(
          ClientMapScreen.clientStatusLabel(
            RideStatus.assigned,
            driverEnRoute: true,
          ),
          'Driver on the way',
        );
      });

      test('assigned default (driverEnRoute omitted) => "Driver assigned"', () {
        // Default is false, so no driver location means "Driver assigned".
        expect(
          ClientMapScreen.clientStatusLabel(RideStatus.assigned),
          'Driver assigned',
        );
      });
    });

    group('non-assigned statuses are unaffected by driverEnRoute', () {
      test('requested => "Finding a driver"', () {
        expect(
          ClientMapScreen.clientStatusLabel(RideStatus.requested),
          'Finding a driver',
        );
      });

      test('inProgress => "On trip"', () {
        expect(
          ClientMapScreen.clientStatusLabel(RideStatus.inProgress),
          'On trip',
        );
      });

      test('completed => "Trip completed"', () {
        expect(
          ClientMapScreen.clientStatusLabel(RideStatus.completed),
          'Trip completed',
        );
      });

      test('cancelled => "Trip cancelled"', () {
        expect(
          ClientMapScreen.clientStatusLabel(RideStatus.cancelled),
          'Trip cancelled',
        );
      });
    });

    test('every RideStatus value produces a non-empty label', () {
      for (final status in RideStatus.values) {
        expect(
          ClientMapScreen.clientStatusLabel(status),
          isNotEmpty,
          reason: 'status $status must return a non-empty label',
        );
      }
    });
  });
}

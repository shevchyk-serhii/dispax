import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/client_map_screen.dart';

void main() {
  group('ClientMapScreen.clientStatusLabel', () {
    test('maps each ride status to a client-facing label', () {
      expect(
        ClientMapScreen.clientStatusLabel(RideStatus.requested),
        'Finding a driver',
      );
      expect(
        ClientMapScreen.clientStatusLabel(RideStatus.assigned),
        'Driver on the way',
      );
      expect(
        ClientMapScreen.clientStatusLabel(RideStatus.inProgress),
        'On trip',
      );
      expect(
        ClientMapScreen.clientStatusLabel(RideStatus.completed),
        'Trip completed',
      );
      expect(
        ClientMapScreen.clientStatusLabel(RideStatus.cancelled),
        'Trip cancelled',
      );
    });

    test('covers every status (no missing case)', () {
      for (final status in RideStatus.values) {
        expect(ClientMapScreen.clientStatusLabel(status), isNotEmpty);
      }
    });
  });
}

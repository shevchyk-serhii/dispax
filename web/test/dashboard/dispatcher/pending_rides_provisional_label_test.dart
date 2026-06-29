import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';

/// Dispatcher lists must show the route (not the "Walk-in" placeholder) for provisional ("from-chat")
/// rides, matching the driver card. Mutation: drop the `ride.clientProvisional` branch in
/// provisionalAwareClientLabel → the provisional case returns "Walk-in" → the first test goes red.
void main() {
  Ride makeRide({required bool provisional, required String clientName}) =>
      Ride(
        id: 'r1',
        clientId: 'c1',
        creatorId: 'u1',
        companyId: 'co1',
        pickupDateTime: DateTime.utc(2090, 1, 1, 10),
        from: const Location(address: 'Munich Airport'),
        to: const Location(address: 'Leopoldstr 5'),
        status: RideStatus.requested,
        clientName: clientName,
        clientProvisional: provisional,
      );

  test('provisional ride shows the route, not the placeholder name', () {
    final label = provisionalAwareClientLabel(
      makeRide(provisional: true, clientName: 'Walk-in'),
    );
    expect(label, 'Munich Airport → Leopoldstr 5');
    expect(label, isNot(contains('Walk-in')));
  });

  test('real client ride shows the client name', () {
    final label = provisionalAwareClientLabel(
      makeRide(provisional: false, clientName: 'Frau Meier'),
    );
    expect(label, 'Frau Meier');
  });
}

// Regression for the dispatcher board never flipping to "Confirmed" live:
// the WS RideConfirmed/RideRejected handler only reloaded the pending list,
// and RideBloc._mergePending keeps non-Requested rides exactly as their local
// copy was — so a confirm never changed the Assigned-tab badge, and a reject
// left a stale Assigned copy next to the freshly reloaded Requested twin.
// liveStatusPatch maps those WS events to an in-place RideStatusReceived patch
// that is dispatched before the reload. Caught end-to-end by the
// e2e_ws_dispatcher_status_live Patrol suite.

import 'package:dispax/dashboard/dispatcher/dispatcher_dashboard.dart';
import 'package:dispax/modules/core/models/websocket_event.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('liveStatusPatch', () {
    test('RideConfirmed → in-place patch to RideStatus.confirmed', () {
      final patch = liveStatusPatch(
        const WebSocketEvent(
          type: 'RideConfirmed',
          rideId: 'ride-1',
          companyId: 'company-1',
        ),
      );

      expect(patch, isNotNull);
      expect(patch!.rideId, 'ride-1');
      expect(patch.newStatus, RideStatus.confirmed);
    });

    test('RideRejected → in-place patch back to RideStatus.requested', () {
      final patch = liveStatusPatch(
        const WebSocketEvent(
          type: 'RideRejected',
          rideId: 'ride-2',
          companyId: 'company-1',
        ),
      );

      expect(patch, isNotNull);
      expect(patch!.rideId, 'ride-2');
      expect(patch.newStatus, RideStatus.requested);
    });

    test('event without a rideId → no patch', () {
      final patch = liveStatusPatch(
        const WebSocketEvent(type: 'RideConfirmed', companyId: 'company-1'),
      );

      expect(patch, isNull);
    });

    test('unrelated event type → no patch', () {
      final patch = liveStatusPatch(
        const WebSocketEvent(
          type: 'RideCreated',
          rideId: 'ride-3',
          companyId: 'company-1',
        ),
      );

      expect(patch, isNull);
    });
  });
}

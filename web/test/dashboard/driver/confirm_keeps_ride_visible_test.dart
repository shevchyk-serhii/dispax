import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';

/// Reproduction harness for the field bug: a multi-role user (dispatcher+driver)
/// on the driver "Today" screen confirms their only active ride and it vanishes
/// from the list until a manual refresh. The driver screen scopes rides via
/// [ridesDrivenBy] (driverId == myId) and shows today's rides via
/// [todayRidesFilter]. After confirm the ride MUST stay visible (it becomes the
/// "live" ride), so it must remain in `ridesDrivenBy(state.rides, myId)` AND in
/// `todayRidesFilter(...)`.
void main() {
  const myId = '11111111-1111-1111-1111-111111111111';
  const rideId = '019eff06-c9d1-722f-8291-8c34215a28f8';

  // A pickup later TODAY (local), so todayRidesFilter keeps it.
  final now = DateTime.now();
  final todayPickup = DateTime(now.year, now.month, now.day, 23, 0);

  /// The exact confirm-endpoint response captured from the running backend,
  /// with pickupDateTime moved to later today so the Today filter applies.
  Map<String, dynamic> confirmJson() => {
    'id': rideId,
    'clientId': '66666666-6666-6666-6666-666666666666',
    'creatorId': '66666666-6666-6666-6666-666666666666',
    'driverId': myId,
    'pickupDateTime': todayPickup.toUtc().toIso8601String(),
    'from': {'address': 'Marienplatz, München'},
    'to': {'address': 'Flughafen München'},
    'status': 'Confirmed',
    'clientName': 'Unknown Client',
    'isAirportTransfer': false,
    'isArrival': false,
    'driverApproaching': false,
    'paymentStatus': 'Unpaid',
    'isVipRide': true,
    'preferredDriverUsed': false,
    'vehicleClass': 'business',
    'confirmed': true,
    'confirmedAt': DateTime.now().toUtc().toIso8601String(),
  };

  Ride assignedRide() => Ride.fromJson({
    ...confirmJson(),
    'status': 'Assigned',
    'confirmed': false,
  });

  late MockRideService mockRideService;

  setUp(() {
    mockRideService = MockRideService();
    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  blocTest<RideBloc, RideState>(
    'after RideConfirmRequested the ride stays visible to the driver '
    '(in ridesDrivenBy AND todayRidesFilter)',
    build: () {
      when(
        () => mockRideService.confirmRide(rideId),
      ).thenAnswer((_) async => Ride.fromJson(confirmJson()));
      return buildBloc();
    },
    seed: () => RideState.loaded([assignedRide()]),
    act: (bloc) => bloc.add(const RideConfirmRequested(rideId: rideId)),
    verify: (bloc) {
      final mine = ridesDrivenBy(bloc.state.rides, myId);
      expect(mine.map((r) => r.id), [
        rideId,
      ], reason: 'confirmed ride must remain scoped to the driver');
      final today = todayRidesFilter(bloc.state.rides, DateTime.now());
      expect(today.map((r) => r.id), [
        rideId,
      ], reason: 'confirmed ride must remain in the Today list');
      expect(mine.single.status, RideStatus.confirmed);
    },
  );
}

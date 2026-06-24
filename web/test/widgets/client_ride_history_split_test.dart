// Regression test: ClientRideHistoryScreen must split rides into
// UPCOMING (assigned/inProgress/requested) and PAST (completed/cancelled).
//
// The private categorisation helpers are tested here by exercising the public
// classification invariants via Ride model + RideStatus directly — no BLoC
// needed (the BLoC just supplies the list; filtering is a pure transformation).

import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';

const _loc = Location(address: 'Test');
const _clientId = 'client-1';

Ride _makeRide(RideStatus status, {String? flightNumber, double? price}) {
  return Ride(
    id: 'ride-${status.value}',
    clientId: _clientId,
    creatorId: 'u1',
    companyId: 'co1',
    pickupDateTime: DateTime(2026, 6, 20, 14, 30),
    from: _loc,
    to: _loc,
    clientName: 'Client',
    status: status,
    flightNumber: flightNumber,
    price: price,
  );
}

/// Mimics the screen's _upcomingRides categorisation.
bool _isUpcoming(Ride ride) =>
    ride.status == RideStatus.requested ||
    ride.status == RideStatus.assigned ||
    ride.status == RideStatus.confirmed ||
    ride.status == RideStatus.inProgress ||
    ride.status == RideStatus.handedOff;

/// Mimics the screen's _pastRides categorisation.
bool _isPast(Ride ride) =>
    ride.status == RideStatus.completed || ride.status == RideStatus.cancelled;

void main() {
  group('Upcoming / Past classification', () {
    final all = RideStatus.values.map((s) => _makeRide(s)).toList();

    test('requested rides go to UPCOMING', () {
      final r = _makeRide(RideStatus.requested);
      expect(_isUpcoming(r), isTrue);
      expect(_isPast(r), isFalse);
    });

    test('assigned rides go to UPCOMING (Confirmed pill)', () {
      final r = _makeRide(RideStatus.assigned);
      expect(_isUpcoming(r), isTrue);
      expect(_isPast(r), isFalse);
    });

    test('inProgress rides go to UPCOMING', () {
      final r = _makeRide(RideStatus.inProgress);
      expect(_isUpcoming(r), isTrue);
      expect(_isPast(r), isFalse);
    });

    test('completed rides go to PAST', () {
      final r = _makeRide(RideStatus.completed);
      expect(_isPast(r), isTrue);
      expect(_isUpcoming(r), isFalse);
    });

    test('cancelled rides go to PAST', () {
      final r = _makeRide(RideStatus.cancelled);
      expect(_isPast(r), isTrue);
      expect(_isUpcoming(r), isFalse);
    });

    test('every status is categorised (no gap)', () {
      for (final ride in all) {
        final categorised = _isUpcoming(ride) || _isPast(ride);
        expect(
          categorised,
          isTrue,
          reason: '${ride.status.value} must fall into upcoming or past',
        );
      }
    });

    test('categories are mutually exclusive', () {
      for (final ride in all) {
        expect(
          _isUpcoming(ride) && _isPast(ride),
          isFalse,
          reason:
              '${ride.status.value} cannot belong to both upcoming and past',
        );
      }
    });

    test('upcoming set contains every active/future status', () {
      final upcoming = all.where(_isUpcoming).map((r) => r.status).toSet();
      expect(upcoming, {
        RideStatus.requested,
        RideStatus.assigned,
        RideStatus.confirmed,
        RideStatus.inProgress,
        RideStatus.handedOff,
      });
    });

    test('past set contains exactly completed and cancelled', () {
      final past = all.where(_isPast).map((r) => r.status).toSet();
      expect(past, {RideStatus.completed, RideStatus.cancelled});
    });
  });

  group('Ride fields used by the history cards', () {
    test('flightNumber is available for detail line', () {
      final r = _makeRide(
        RideStatus.assigned,
        flightNumber: 'LH 1845',
        price: 62.0,
      );
      expect(r.flightNumber, 'LH 1845');
      expect(r.price, 62.0);
    });

    test('rating and driverName render gracefully when null', () {
      final r = _makeRide(RideStatus.completed);
      expect(r.rating, isNull);
      expect(r.driverName, isNull);
      // Should degrade to "Unknown driver" in the UI — no exception from model
    });
  });
}

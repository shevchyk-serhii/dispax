import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/create_ride_request.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/helpers/tag_helpers.dart';

Ride _rideWithTags(List<String> tags) => Ride(
  id: 'r1',
  clientId: 'c1',
  creatorId: 'cr1',
  companyId: 'co1',
  pickupDateTime: DateTime(2026, 3, 15, 10),
  from: const Location(address: 'A'),
  to: const Location(address: 'B'),
  clientName: 'Client',
  tags: tags,
);

void main() {
  group('Ride tags JSON', () {
    test('round-trips tags through toJson/fromJson', () {
      final ride = _rideWithTags(['Urgent', 'Cash']);
      final restored = Ride.fromJson(ride.toJson());
      expect(restored.tags, ['Urgent', 'Cash']);
    });

    test('missing tags key parses as empty list', () {
      final json = _rideWithTags([]).toJson()..remove('tags');
      final restored = Ride.fromJson(json);
      expect(restored.tags, isEmpty);
    });

    test('copyWith replaces tags', () {
      final ride = _rideWithTags(['A']);
      expect(ride.copyWith(tags: ['B', 'C']).tags, ['B', 'C']);
      // omitting tags keeps the existing list
      expect(ride.copyWith(clientName: 'X').tags, ['A']);
    });
  });

  group('CreateRideRequest tags', () {
    CreateRideRequest req(List<String>? tags) => CreateRideRequest(
      clientId: 'c1',
      creatorId: 'cr1',
      companyId: 'co1',
      from: const Location(address: 'A'),
      to: const Location(address: 'B'),
      clientName: 'Client',
      manualPickupDateTime: DateTime(2026, 3, 15, 10),
      tags: tags,
    );

    test('serializes tags as a JSON array (not a joined string)', () {
      final json = req(['Urgent', 'Cash']).toJson();
      expect(json['tags'], isA<List>());
      expect(json['tags'], ['Urgent', 'Cash']);
    });

    test('omits tags when null or empty', () {
      expect(req(null).toJson().containsKey('tags'), isFalse);
      expect(req([]).toJson().containsKey('tags'), isFalse);
    });
  });

  group('tag_helpers', () {
    test('normalizeTag trims and collapses whitespace', () {
      expect(normalizeTag('  Cash   Only '), 'Cash Only');
      expect(normalizeTag('   '), '');
    });

    test('rideHasTag is case-insensitive', () {
      final ride = _rideWithTags(['Urgent']);
      expect(rideHasTag(ride, 'urgent'), isTrue);
      expect(rideHasTag(ride, 'cash'), isFalse);
    });

    test('distinctTagsFromRides de-dups case-insensitively and sorts', () {
      final rides = [
        _rideWithTags(['Urgent', 'cash']),
        _rideWithTags(['urgent', 'VIP']),
      ];
      expect(distinctTagsFromRides(rides), ['cash', 'Urgent', 'VIP']);
    });
  });
}

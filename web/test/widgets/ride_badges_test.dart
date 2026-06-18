import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/driver/calendar/widgets/ride_badges.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';

Ride _ride({
  bool isAirportTransfer = false,
  bool isArrival = false,
  String? flightNumber,
  String? flightStatus,
  String? gate,
  String? terminal,
  String? airportCheckpoint,
  bool isVipRide = false,
  String? paymentStatus,
  String? paymentMethod,
  String? specialRequirements,
  String? notes,
  double? price,
}) {
  const loc = Location(address: 'Somewhere');
  return Ride(
    id: 'r1',
    clientId: 'c1',
    creatorId: 'u1',
    companyId: 'co1',
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
    from: loc,
    to: loc,
    clientName: 'Client',
    isAirportTransfer: isAirportTransfer,
    isArrival: isArrival,
    flightNumber: flightNumber,
    flightStatus: flightStatus,
    gate: gate,
    terminal: terminal,
    airportCheckpoint: airportCheckpoint,
    isVipRide: isVipRide,
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    specialRequirements: specialRequirements,
    notes: notes,
    price: price,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('RideBadges.chips', () {
    testWidgets('shows nothing for a plain ride', (tester) async {
      await _pump(
        tester,
        Builder(builder: (ctx) => RideBadges.chips(ctx, _ride())),
      );

      expect(find.byType(Wrap), findsNothing);
      expect(find.byIcon(Icons.flight_land), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows flight, checkpoint, VIP and payment badges', (
      tester,
    ) async {
      final ride = _ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH123',
        flightStatus: 'Delayed',
        terminal: '2',
        airportCheckpoint: 'landed',
        isVipRide: true,
        paymentStatus: 'paid',
        paymentMethod: 'Card',
      );

      await _pump(
        tester,
        Builder(builder: (ctx) => RideBadges.chips(ctx, ride)),
      );

      expect(find.textContaining('LH123'), findsOneWidget);
      expect(find.text('Landed'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.textContaining('Paid'), findsOneWidget);
      expect(find.textContaining('Card'), findsOneWidget);
    });

    testWidgets('payment badge reads Unpaid when not paid', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (ctx) =>
              RideBadges.chips(ctx, _ride(paymentStatus: 'pending')),
        ),
      );

      expect(find.textContaining('Unpaid'), findsOneWidget);
    });
  });

  group('RideBadges.dayMarkers', () {
    testWidgets('hidden for plain rides', (tester) async {
      await _pump(
        tester,
        Builder(builder: (ctx) => RideBadges.dayMarkers(ctx, [_ride()])),
      );

      expect(find.byIcon(Icons.flight), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows airport, VIP and requirements icons across a set', (
      tester,
    ) async {
      final rides = [
        _ride(isAirportTransfer: true, flightNumber: 'LH1'),
        _ride(isVipRide: true),
        _ride(specialRequirements: 'Child seat'),
      ];

      await _pump(
        tester,
        Builder(builder: (ctx) => RideBadges.dayMarkers(ctx, rides)),
      );

      expect(find.byIcon(Icons.flight), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });
  });

  group('RideBadges.tooltip', () {
    test('summarises client, flight, VIP, price and destination', () {
      final ride = _ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH123',
        terminal: '2',
        isVipRide: true,
        price: 42.5,
      );

      final text = RideBadges.tooltip(ride);

      expect(text, contains('Client'));
      expect(text, contains('LH123'));
      expect(text, contains('VIP'));
      expect(text, contains('42.50'));
    });
  });

  group('RideBadges.requirements', () {
    testWidgets('hidden when no requirements or notes', (tester) async {
      await _pump(
        tester,
        Builder(builder: (ctx) => RideBadges.requirements(ctx, _ride())),
      );

      expect(find.byIcon(Icons.priority_high), findsNothing);
    });

    testWidgets('joins special requirements and notes', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (ctx) => RideBadges.requirements(
            ctx,
            _ride(specialRequirements: 'Child seat', notes: 'Extra luggage'),
          ),
        ),
      );

      expect(find.byIcon(Icons.priority_high), findsOneWidget);
      expect(find.textContaining('Child seat'), findsOneWidget);
      expect(find.textContaining('Extra luggage'), findsOneWidget);
    });
  });
}

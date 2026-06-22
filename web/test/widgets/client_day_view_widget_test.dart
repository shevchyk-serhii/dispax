// Tests for ClientDayViewWidget.
//
// Verifies that the client day-view:
//   1. Only renders rides whose pickupDateTime falls on selectedDay.
//   2. Shows the empty state ('No rides scheduled') when there are no rides for the day.
//   3. Never shows driver-only action controls (phone, navigation, Start, Complete).
//   4. Never opens a price-editing dialog — onPriceEdited is always null.
//   5. Calls onRideSelected with the correct Ride when a card is tapped.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/dashboard/client/calendar/client_day_view_widget.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

// A fixed reference date used as the "selected day" throughout the tests.
// Not const because DateTime constructor is not const in Dart.
DateTime get _selectedDay => DateTime(2026, 6, 22);

Location _loc(String address) => Location(address: address);

Ride _ride({
  required String id,
  required DateTime pickupDateTime,
  String fromAddress = 'From St',
  String toAddress = 'To Ave',
  RideStatus status = RideStatus.assigned,
}) {
  return Ride(
    id: id,
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: pickupDateTime,
    from: _loc(fromAddress),
    to: _loc(toAddress),
    clientName: 'Test Client',
    status: status,
  );
}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  _MockRideBloc rideBloc, {
  DateTime? selectedDay,
  void Function(Ride)? onRideSelected,
}) async {
  final day = selectedDay ?? _selectedDay;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: BlocProvider<RideBloc>.value(
        value: rideBloc,
        child: Scaffold(
          body: ClientDayViewWidget(
            selectedDay: day,
            onRideSelected: onRideSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockRideBloc rideBloc;

  setUp(() {
    rideBloc = _MockRideBloc();
  });

  // ── Day filtering ──────────────────────────────────────────────────────────

  group('ClientDayViewWidget — day filtering', () {
    testWidgets('shows only the ride whose pickupDateTime is on selectedDay', (
      tester,
    ) async {
      final rideOnDay = _ride(
        id: 'r-target',
        pickupDateTime: DateTime(2026, 6, 22, 10, 0),
        fromAddress: 'Airport Munich',
        toAddress: 'Marienplatz',
      );
      final rideOtherDay = _ride(
        id: 'r-other',
        pickupDateTime: DateTime(2026, 6, 23, 10, 0),
        fromAddress: 'Hauptbahnhof',
        toAddress: 'Englischer Garten',
      );

      when(
        () => rideBloc.state,
      ).thenReturn(RideState.loaded([rideOnDay, rideOtherDay]));

      await _pump(tester, rideBloc);

      // Ride on selected day visible.
      expect(find.textContaining('Airport Munich'), findsOneWidget);
      // Ride on the other day must not appear.
      expect(find.textContaining('Hauptbahnhof'), findsNothing);
    });

    testWidgets('shows two rides when both share the same pickupDate', (
      tester,
    ) async {
      final ride1 = _ride(
        id: 'r1',
        pickupDateTime: DateTime(2026, 6, 22, 9, 0),
        fromAddress: 'Pickup A',
        toAddress: 'Drop A',
      );
      final ride2 = _ride(
        id: 'r2',
        pickupDateTime: DateTime(2026, 6, 22, 14, 0),
        fromAddress: 'Pickup B',
        toAddress: 'Drop B',
      );

      when(() => rideBloc.state).thenReturn(RideState.loaded([ride1, ride2]));

      await _pump(tester, rideBloc);

      expect(find.textContaining('Pickup A'), findsOneWidget);
      expect(find.textContaining('Pickup B'), findsOneWidget);
    });

    testWidgets('midnight boundary: ride at 00:00 on selectedDay is shown', (
      tester,
    ) async {
      final midnightRide = _ride(
        id: 'midnight',
        pickupDateTime: DateTime(2026, 6, 22, 0, 0),
        fromAddress: 'Night Start',
        toAddress: 'Night End',
      );

      when(() => rideBloc.state).thenReturn(RideState.loaded([midnightRide]));

      await _pump(tester, rideBloc);

      expect(find.textContaining('Night Start'), findsOneWidget);
    });
  });

  // ── Empty state ────────────────────────────────────────────────────────────

  group('ClientDayViewWidget — empty state', () {
    testWidgets("shows 'No rides scheduled' when RideState has no rides", (
      tester,
    ) async {
      when(() => rideBloc.state).thenReturn(RideState.loaded(const []));

      await _pump(tester, rideBloc);

      expect(find.text('No rides scheduled'), findsOneWidget);
    });

    testWidgets(
      "shows 'No rides scheduled' when all rides belong to a different day",
      (tester) async {
        final otherDay = _ride(
          id: 'other',
          pickupDateTime: DateTime(2026, 7, 1, 12, 0),
        );
        when(() => rideBloc.state).thenReturn(RideState.loaded([otherDay]));

        await _pump(tester, rideBloc);

        expect(find.text('No rides scheduled'), findsOneWidget);
      },
    );
  });

  // ── No driver action controls ──────────────────────────────────────────────

  group('ClientDayViewWidget — no driver-specific action buttons', () {
    setUp(() {
      final ride = _ride(
        id: 'r-actions',
        pickupDateTime: DateTime(2026, 6, 22, 10, 0),
      );
      when(() => rideBloc.state).thenReturn(RideState.loaded([ride]));
    });

    testWidgets('phone icon is absent', (tester) async {
      await _pump(tester, rideBloc);
      expect(find.byIcon(Icons.phone), findsNothing);
    });

    testWidgets('navigation icon is absent', (tester) async {
      await _pump(tester, rideBloc);
      expect(find.byIcon(Icons.navigation), findsNothing);
    });

    testWidgets("'Start' button label is absent", (tester) async {
      await _pump(tester, rideBloc);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets("'Complete' button label is absent", (tester) async {
      await _pump(tester, rideBloc);
      expect(find.text('Complete'), findsNothing);
    });
  });

  // ── No price-editing dialog ────────────────────────────────────────────────

  group('ClientDayViewWidget — price is read-only', () {
    testWidgets("'Set ride price' dialog never opens (onPriceEdited is null)", (
      tester,
    ) async {
      final ride = _ride(
        id: 'r-price',
        pickupDateTime: DateTime(2026, 6, 22, 10, 0),
      );
      when(() => rideBloc.state).thenReturn(RideState.loaded([ride]));

      await _pump(tester, rideBloc);

      // Tap the card area — no dialog should appear.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Set ride price'), findsNothing);
    });

    testWidgets("'Set price' label is not rendered when card has no price", (
      tester,
    ) async {
      final ride = _ride(
        id: 'r-noprice',
        pickupDateTime: DateTime(2026, 6, 22, 10, 0),
      );
      when(() => rideBloc.state).thenReturn(RideState.loaded([ride]));

      await _pump(tester, rideBloc);

      // The driver-only "Set price" affordance must not appear for clients.
      expect(find.text('Set price'), findsNothing);
    });
  });

  // ── Compact layout: no duplicated date header ───────────────────────────────

  group('ClientDayViewWidget — compact header', () {
    testWidgets(
      'does not render its own large weekday/date header (date lives in '
      'CalendarControls above)',
      (tester) async {
        // selectedDay = 2026-06-22 is a Monday.
        when(() => rideBloc.state).thenReturn(RideState.loaded(const []));

        await _pump(tester, rideBloc);

        // The day card used to repeat "Monday" + "Jun 22, 2026" as a big
        // header; that duplication is removed to free vertical space.
        expect(find.text('Monday'), findsNothing);
        expect(find.text('Jun 22, 2026'), findsNothing);
      },
    );
  });

  // ── onRideSelected callback ────────────────────────────────────────────────

  group('ClientDayViewWidget — onRideSelected callback', () {
    testWidgets('tapping a ride card calls onRideSelected with that ride', (
      tester,
    ) async {
      final expectedRide = _ride(
        id: 'r-tap',
        pickupDateTime: DateTime(2026, 6, 22, 11, 30),
        fromAddress: 'Tap From',
        toAddress: 'Tap To',
      );
      when(() => rideBloc.state).thenReturn(RideState.loaded([expectedRide]));

      Ride? captured;
      await _pump(tester, rideBloc, onRideSelected: (r) => captured = r);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.id, equals('r-tap'));
    });

    testWidgets(
      'tapping the correct card among multiple calls back with matching ride',
      (tester) async {
        final ride1 = _ride(
          id: 'r-first',
          pickupDateTime: DateTime(2026, 6, 22, 9, 0),
          fromAddress: 'First From',
          toAddress: 'First To',
        );
        final ride2 = _ride(
          id: 'r-second',
          pickupDateTime: DateTime(2026, 6, 22, 15, 0),
          fromAddress: 'Second From',
          toAddress: 'Second To',
        );
        when(() => rideBloc.state).thenReturn(RideState.loaded([ride1, ride2]));

        Ride? captured;
        await _pump(tester, rideBloc, onRideSelected: (r) => captured = r);

        // Tap the first InkWell (earliest ride is sorted first).
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(captured, isNotNull);
        expect(captured!.id, equals('r-first'));
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/driver/calendar/widgets/ride_calendar_card.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';

// ── Ride fixtures ─────────────────────────────────────────────────────────────

const _loc = Location(address: 'Somewhere');

Ride _ride({double? price, String? driverId}) {
  return Ride(
    id: 'ride-1',
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 6, 22, 9, 0),
    from: _loc,
    to: _loc,
    clientName: 'Test Client',
    status: RideStatus.assigned,
    driverId: driverId,
    price: price,
  );
}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: Scaffold(body: SizedBox(height: 500, child: child)),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('RideCalendarCard — price display', () {
    testWidgets('shows formatted price when price is not null', (tester) async {
      await _pump(tester, RideCalendarCard(ride: _ride(price: 49.99)));
      expect(find.text('€49.99'), findsOneWidget);
    });

    testWidgets(
      'shows "Set price" label when price is null and onPriceEdited provided',
      (tester) async {
        await _pump(
          tester,
          RideCalendarCard(ride: _ride(), onPriceEdited: (_) {}),
        );
        expect(find.text('Set price'), findsOneWidget);
      },
    );

    testWidgets(
      'hides "Set price" label when price is null and onPriceEdited is null',
      (tester) async {
        await _pump(tester, RideCalendarCard(ride: _ride()));
        // Neither a price text nor the "Set price" affordance should appear.
        expect(find.text('Set price'), findsNothing);
      },
    );
  });

  group('RideCalendarCard — price dialog', () {
    testWidgets('tapping price with onPriceEdited opens numeric dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        RideCalendarCard(ride: _ride(price: 30.00), onPriceEdited: (_) {}),
      );

      await tester.tap(find.text('€30.00'));
      await tester.pumpAndSettle();

      // The AlertDialog title must be visible.
      expect(find.text('Set ride price'), findsOneWidget);
    });

    testWidgets('tapping "Set price" label opens numeric dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        RideCalendarCard(ride: _ride(), onPriceEdited: (_) {}),
      );

      await tester.tap(find.text('Set price'));
      await tester.pumpAndSettle();

      expect(find.text('Set ride price'), findsOneWidget);
    });

    testWidgets(
      'confirming a valid price calls onPriceEdited with parsed value',
      (tester) async {
        double? captured;
        await _pump(
          tester,
          RideCalendarCard(ride: _ride(), onPriceEdited: (v) => captured = v),
        );

        await tester.tap(find.text('Set price'));
        await tester.pumpAndSettle();

        // Clear pre-filled text and enter a new value.
        final textField = find.byType(TextField);
        await tester.enterText(textField, '55.50');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(captured, closeTo(55.50, 0.001));
      },
    );

    testWidgets('cancelling the dialog does not call onPriceEdited', (
      tester,
    ) async {
      bool called = false;
      await _pump(
        tester,
        RideCalendarCard(ride: _ride(), onPriceEdited: (_) => called = true),
      );

      await tester.tap(find.text('Set price'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });

    testWidgets('price tapping is no-op when onPriceEdited is null', (
      tester,
    ) async {
      // When onPriceEdited is null tapping the price region must not open a dialog.
      await _pump(
        tester,
        RideCalendarCard(
          ride: _ride(price: 20.00),
          // onPriceEdited intentionally omitted
        ),
      );

      await tester.tap(find.text('€20.00'));
      await tester.pump();

      expect(find.text('Set ride price'), findsNothing);
    });

    testWidgets(
      'entering a negative price in dialog — Confirm button ignores it',
      (tester) async {
        // The dialog's Confirm action only accepts value >= 0; negative input is silently rejected
        // and the callback must not be called.
        double? captured;
        await _pump(
          tester,
          RideCalendarCard(ride: _ride(), onPriceEdited: (v) => captured = v),
        );

        await tester.tap(find.text('Set price'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '-5');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(captured, isNull);
      },
    );
  });

  group('RideCalendarCard — showActions flag', () {
    testWidgets(
      'actionsWidget is rendered when showActions=true and widget provided',
      (tester) async {
        const tag = 'actions-tag';
        await _pump(
          tester,
          RideCalendarCard(
            ride: _ride(),
            showActions: true,
            actionsWidget: const Text(tag),
          ),
        );
        expect(find.text(tag), findsOneWidget);
      },
    );

    testWidgets('actionsWidget is hidden when showActions=false', (
      tester,
    ) async {
      const tag = 'actions-hidden';
      await _pump(
        tester,
        RideCalendarCard(
          ride: _ride(),
          showActions: false,
          actionsWidget: const Text(tag),
        ),
      );
      expect(find.text(tag), findsNothing);
    });
  });

  group('RideCalendarCard — onTap callback', () {
    testWidgets('tapping the card calls onTap', (tester) async {
      bool tapped = false;
      await _pump(
        tester,
        RideCalendarCard(ride: _ride(), onTap: () => tapped = true),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('RideCalendarCard — client / location display', () {
    testWidgets('renders clientName and address fields', (tester) async {
      await _pump(
        tester,
        RideCalendarCard(
          ride: Ride(
            id: 'r2',
            clientId: 'c2',
            creatorId: 'u2',
            companyId: 'co2',
            pickupDateTime: DateTime(2026, 6, 22, 14, 0),
            from: const Location(address: 'From Street'),
            to: const Location(address: 'To Avenue'),
            clientName: 'Maria Schmidt',
          ),
        ),
      );

      expect(find.textContaining('Maria Schmidt'), findsOneWidget);
      expect(find.textContaining('From Street'), findsOneWidget);
      expect(find.textContaining('To Avenue'), findsOneWidget);
    });
  });

  // ── Compact mode — overflow regression ────────────────────────────────────

  group('RideCalendarCard — compact mode (overflow regression)', () {
    const longClientName = 'BMWAG-HerrSchneiderVonMünchenGmbHLongName';
    const longAddress = 'Flughafenstraße 100, Terminal 2, München-Flughafen';

    /// Pumps the card inside a narrow 120 px wide box — the width that used to
    /// reliably trigger RIGHT OVERFLOWED BY ~200 px in the old code.
    Future<void> pumpCompact(
      WidgetTester tester, {
      bool compact = true,
      DateTime? pickupDateTime,
    }) async {
      final ride = Ride(
        id: 'compact-1',
        clientId: 'c1',
        creatorId: 'u1',
        companyId: 'co1',
        pickupDateTime: pickupDateTime ?? DateTime(2026, 6, 22, 9, 30),
        from: const Location(address: longAddress),
        to: const Location(address: longAddress),
        clientName: longClientName,
        status: RideStatus.assigned,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 400,
              child: RideCalendarCard(
                ride: ride,
                compact: compact,
                showActions: false,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'no layout overflow exception at narrow width when compact is true',
      (tester) async {
        await pumpCompact(tester, compact: true);
        // If there were a RenderFlex overflow, Flutter would set an exception
        // on tester. A null exception means the card rendered without overflow.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('compact mode renders no client name or address text at all', (
      tester,
    ) async {
      // Compact cards show only time + price; the client/location rows are
      // omitted entirely (they open on tap). This is the regression guard:
      // the long unbreakable client/address strings that used to stack one
      // letter per line must not be in the tree.
      await pumpCompact(tester, compact: true);
      expect(find.textContaining(longClientName), findsNothing);
      expect(find.textContaining(longAddress), findsNothing);
      expect(find.textContaining('Client'), findsNothing);
      expect(find.textContaining('From'), findsNothing);
      expect(find.textContaining('To'), findsNothing);
    });

    testWidgets(
      'compact false (default) at narrow width raises overflow (opt-in guard)',
      (tester) async {
        // Flutter test captures RenderFlex overflow as a FlutterError.
        // Assert it is non-null to confirm compact:false does NOT suppress overflow,
        // i.e. the fix is genuinely opt-in and the day-view is unaffected.
        await pumpCompact(tester, compact: false);
        final exception = tester.takeException();
        expect(exception, isNotNull);
      },
    );

    testWidgets('compact header shows pickup time as HH:mm', (tester) async {
      await pumpCompact(
        tester,
        compact: true,
        pickupDateTime: DateTime(2026, 6, 22, 9, 30),
      );
      expect(find.text('09:30'), findsWidgets);
    });

    testWidgets('compact with showActions:false renders no actionsWidget', (
      tester,
    ) async {
      const actionTag = 'compact-actions-tag';
      final ride = Ride(
        id: 'compact-2',
        clientId: 'c1',
        creatorId: 'u1',
        companyId: 'co1',
        pickupDateTime: DateTime(2026, 6, 22, 10, 0),
        from: const Location(address: 'A'),
        to: const Location(address: 'B'),
        clientName: 'Client',
        status: RideStatus.assigned,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 400,
              child: RideCalendarCard(
                ride: ride,
                compact: true,
                showActions: false,
                actionsWidget: const Text(actionTag),
              ),
            ),
          ),
        ),
      );
      expect(find.text(actionTag), findsNothing);
    });
  });
}

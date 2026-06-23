import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/widgets/common/cancel_ride_dialog.dart';
import 'package:dispax/modules/core/models/person.dart';

void main() {
  // Pumps the dialog for the given role and opens the reason dropdown so its
  // items are visible in the widget tree.
  Future<void> openReasons(WidgetTester tester, PersonRole role) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(body: CancelRideDialog(role: role)),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
  }

  group('CancelRideDialog reasons by role', () {
    testWidgets('client sees only client-side reasons', (tester) async {
      await openReasons(tester, PersonRole.client);

      // Allowed for a client.
      expect(find.text('Client Request'), findsWidgets);
      expect(find.text('Weather'), findsWidgets);
      expect(find.text('Other'), findsWidgets);

      // Staff-only reasons must NOT be offered to a client.
      expect(find.text('Client No-Show'), findsNothing);
      expect(find.text('Driver Unavailable'), findsNothing);
      expect(find.text('Vehicle Issue'), findsNothing);
    });

    testWidgets('dispatcher sees the full reason list', (tester) async {
      await openReasons(tester, PersonRole.dispatcher);

      expect(find.text('Client No-Show'), findsWidgets);
      expect(find.text('Driver Unavailable'), findsWidgets);
      expect(find.text('Vehicle Issue'), findsWidgets);
      expect(find.text('Client Request'), findsWidgets);
    });

    testWidgets('driver sees the full reason list', (tester) async {
      await openReasons(tester, PersonRole.driver);

      expect(find.text('Client No-Show'), findsWidgets);
      expect(find.text('Vehicle Issue'), findsWidgets);
    });
  });

  group('CancelRideDialog fee field by role', () {
    testWidgets('client cannot set a cancellation fee', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: const Locale('en'),
          home: const Scaffold(body: CancelRideDialog(role: PersonRole.client)),
        ),
      );

      expect(find.text('Cancellation Fee (optional)'), findsNothing);
    });

    testWidgets('dispatcher can set a cancellation fee', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: const Locale('en'),
          home: const Scaffold(
            body: CancelRideDialog(role: PersonRole.dispatcher),
          ),
        ),
      );

      expect(find.text('Cancellation Fee (optional)'), findsOneWidget);
    });
  });

  testWidgets('returns the canonical wire value, not the label', (
    tester,
  ) async {
    Map<String, dynamic>? popped;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await showDialog<Map<String, dynamic>?>(
                  context: context,
                  builder: (_) =>
                      const CancelRideDialog(role: PersonRole.client),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Select "Client Request" from the dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client Request').last);
    await tester.pumpAndSettle();

    // Confirm cancellation.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Ride'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!['reason'], 'client_request');
  });
}

// Tests for DriverClientPriceRow when the ride has clientProvisional = true.
//
// The row must render the "From chat" label and "Add client details" action
// instead of the placeholder name when clientProvisional is true.

import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Ride _provisionalRide({String? placeholderName, double? price}) {
  return Ride(
    id: 'ride-provisional',
    clientId: 'provisional-client-id',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 6, 1, 10, 0),
    from: Location(address: 'Pickup St'),
    to: Location(address: 'Dropoff St'),
    status: RideStatus.requested,
    clientName: placeholderName ?? 'CHAT_placeholder_XYZ',
    clientProvisional: true,
    price: price,
  );
}

Future<void> pumpRow(
  WidgetTester tester, {
  String? clientName,
  double? price,
}) async {
  final apiClient = _MockApiClient();
  when(() => apiClient.getBytes(any())).thenAnswer((_) async => null);

  final ride = _provisionalRide(placeholderName: clientName, price: price);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: DriverClientPriceRow(
              ride: ride,
              isDark: false,
              apiClient: apiClient,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DriverClientPriceRow — provisional ride', () {
    testWidgets('shows "From chat" label instead of placeholder name', (
      tester,
    ) async {
      await pumpRow(tester, clientName: 'CHAT_placeholder_XYZ');

      // The l10n key "fromChatRide" = "From chat" (EN).
      expect(find.text('From chat'), findsOneWidget);
      // The placeholder name must NOT be visible.
      expect(find.text('CHAT_placeholder_XYZ'), findsNothing);
    });

    testWidgets('shows "Add client details" action button', (tester) async {
      await pumpRow(tester);
      // The l10n key "linkClient" = "Add client details" (EN).
      expect(find.text('Add client details'), findsOneWidget);
    });

    testWidgets('shows the chat icon (not the avatar)', (tester) async {
      await pumpRow(tester);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('also renders the price when present on a provisional ride', (
      tester,
    ) async {
      await pumpRow(tester, price: 55.0);
      expect(find.text('From chat'), findsOneWidget);
      expect(find.byIcon(Icons.euro), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
    });

    testWidgets(
      'renders "From chat" even when there is no price (no early return)',
      (tester) async {
        await pumpRow(tester, price: null);
        // Must render the label even with no price (tests the early-return guard).
        expect(find.text('From chat'), findsOneWidget);
      },
    );

    testWidgets(
      'mutation check: without clientProvisional branch, placeholder name shows',
      (tester) async {
        // Build a non-provisional ride (clientProvisional = false) to simulate
        // the "fix reverted" state. The placeholder name WOULD be shown.
        final apiClient = _MockApiClient();
        when(() => apiClient.getBytes(any())).thenAnswer((_) async => null);

        // A ride with clientProvisional = false (the old behavior).
        final nonProvisionalRide = Ride(
          id: 'ride-2',
          clientId: 'client-1',
          creatorId: 'creator-1',
          companyId: 'company-1',
          pickupDateTime: DateTime(2026, 6, 1, 10, 0),
          from: Location(address: 'Pickup St'),
          to: Location(address: 'Dropoff St'),
          status: RideStatus.requested,
          clientName: 'Real Client Name',
          clientProvisional: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: DriverClientPriceRow(
                    ride: nonProvisionalRide,
                    isDark: false,
                    apiClient: apiClient,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Non-provisional → "From chat" label must NOT appear.
        expect(find.text('From chat'), findsNothing);
        // The real client name IS shown (non-provisional path).
        expect(find.text('Real Client Name'), findsOneWidget);
      },
    );
  });
}

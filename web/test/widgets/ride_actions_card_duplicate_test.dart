import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/ride_actions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Ride _ride(RideStatus status) => Ride(
  id: 'ride-1',
  clientId: 'client-1',
  creatorId: 'creator-1',
  companyId: 'company-1',
  pickupDateTime: DateTime(2026, 1, 1, 8, 0),
  from: Location(address: 'Marienplatz'),
  to: Location(address: 'Flughafen'),
  status: status,
  clientName: 'BMW AG',
);

Widget _host(Ride ride, {VoidCallback? onDuplicateRide}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: RideActionsCard(ride: ride, onDuplicateRide: onDuplicateRide),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a Duplicate action even for a completed ride', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_ride(RideStatus.completed), onDuplicateRide: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Duplicate'), findsOneWidget);
  });

  testWidgets('tapping Duplicate invokes the callback', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(_ride(RideStatus.cancelled), onDuplicateRide: () => tapped++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duplicate'));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('no Duplicate action when the callback is absent', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_ride(RideStatus.requested)));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate'), findsNothing);
  });
}

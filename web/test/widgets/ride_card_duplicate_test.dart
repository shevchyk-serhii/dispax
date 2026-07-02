import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/ride_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = Location(address: 'Maximilianstraße 10, München');

Ride _ride() => Ride(
  id: 'ride-1',
  clientId: 'client-1',
  creatorId: 'creator-1',
  companyId: 'company-1',
  pickupDateTime: DateTime(2026, 6, 24, 10),
  from: _loc,
  to: _loc,
  clientName: 'BMW AG',
  status: RideStatus.completed,
);

Future<void> _pump(WidgetTester tester, {VoidCallback? onDuplicate}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: RideCard(ride: _ride(), onDuplicate: onDuplicate),
      ),
    ),
  );
}

void main() {
  testWidgets('popup offers Duplicate and invokes the callback', (
    tester,
  ) async {
    var duplicated = false;
    await _pump(tester, onDuplicate: () => duplicated = true);

    // The popup is the only action affordance on the card.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate'), findsOneWidget);

    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(duplicated, isTrue);
  });

  testWidgets('no actions menu when no callbacks are provided', (tester) async {
    await _pump(tester);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}

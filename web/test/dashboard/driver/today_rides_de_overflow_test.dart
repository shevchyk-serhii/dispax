// Locale-dimension regression guard for TodayRideCard layout. The English-only
// overflow test (today_rides_overflow_test.dart) passed while the card overflowed
// on a real German device, because German labels ("Fahrt abschließen", "In
// Bearbeitung", "Details ansehen") are wider than English. This locks the DE
// locale across every status that renders a status button/pill so a locale-
// specific overflow can't regress unseen.
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/driver_management/widgets/today_ride_card.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = Location(address: 'Maximilianstraße 10, 80539 München');

void main() {
  // Every status that renders a status button/pill, where a long German label
  // could steal width and overflow the header chip row or the action row.
  for (final status in [RideStatus.inProgress, RideStatus.confirmed, RideStatus.assigned]) {
    testWidgets('DE locale: $status renders without RenderFlex overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TodayRideCard(
          ride: Ride(id: 'r', clientId: 'c', creatorId: 'cr', companyId: 'co',
            pickupDateTime: DateTime.now().add(const Duration(minutes: 3)),
            from: _loc, to: _loc, clientName: 'BMW AG - Herr Schneider',
            status: status, etaMinutes: 4),
          approachingDistanceMeters: 368, etaMinutes: 4, onViewDetails: () {},
        )),
      ));
      expect(tester.takeException(), isNull, reason: 'DE labels must not overflow ($status)');
    });
  }
}

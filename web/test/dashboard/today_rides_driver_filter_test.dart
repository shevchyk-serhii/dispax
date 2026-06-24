import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('ridesDrivenBy', () {
    test('keeps only rides assigned to the given driver', () {
      final rides = [
        TestFixtures.ride(id: 'mine-1', driverId: 'me'),
        TestFixtures.ride(id: 'other-1', driverId: 'someone-else'),
        TestFixtures.ride(id: 'mine-2', driverId: 'me'),
      ];

      final result = ridesDrivenBy(rides, 'me');

      expect(result.map((r) => r.id), ['mine-1', 'mine-2']);
    });

    test('drops unassigned rides (driverId == null)', () {
      final rides = [
        TestFixtures.ride(id: 'mine', driverId: 'me'),
        TestFixtures.ride(id: 'unassigned'), // driverId defaults to null
      ];

      final result = ridesDrivenBy(rides, 'me');

      expect(result.map((r) => r.id), ['mine']);
    });

    test('returns empty when none of the rides belong to the driver', () {
      final rides = [
        TestFixtures.ride(id: 'a', driverId: 'driver-a'),
        TestFixtures.ride(id: 'b', driverId: 'driver-b'),
      ];

      expect(ridesDrivenBy(rides, 'me'), isEmpty);
    });

    test('returns empty for an empty input list', () {
      expect(ridesDrivenBy(const <Ride>[], 'me'), isEmpty);
    });
  });

  group('rideErrorMessageOrFallback', () {
    /// Pumps a [Builder] so the helper can be called with a real
    /// [BuildContext]. When [withL10n] is true the localization delegates are
    /// installed so AppLocalizations resolves; otherwise the helper must fall
    /// back to the plain literal.
    Future<String> resolve(
      WidgetTester tester,
      String? errorMessage, {
      required bool withL10n,
    }) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: withL10n
              ? AppLocalizations.localizationsDelegates
              : const [],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              result = rideErrorMessageOrFallback(errorMessage, context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('returns the error message verbatim when non-null', (
      tester,
    ) async {
      final result = await resolve(
        tester,
        'Boom: server exploded',
        withL10n: true,
      );
      expect(result, 'Boom: server exploded');
    });

    // Regression guard for the "Null check operator used on a null value"
    // crash: a null errorMessage must yield the localized fallback, never throw.
    testWidgets('returns the localized fallback when the message is null', (
      tester,
    ) async {
      final result = await resolve(tester, null, withL10n: true);
      expect(result, 'Failed to load rides');
    });

    testWidgets(
      'returns the literal fallback when message is null and no l10n is present',
      (tester) async {
        final result = await resolve(tester, null, withL10n: false);
        expect(result, 'Failed to load rides');
      },
    );
  });
}

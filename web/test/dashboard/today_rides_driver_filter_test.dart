import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
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
      RideState state, {
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
              result = rideErrorMessageOrFallback(state, context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    // The helper must route through friendlyError (the canonical error-UX
    // pattern): a typed ApiException cause maps to the localized message and
    // the raw technical text never reaches the UI.
    testWidgets('maps an ApiException cause to the friendly localized text', (
      tester,
    ) async {
      final state = RideState(
        status: RideStateStatus.error,
        errorMessage: 'Failed to load rides: ApiException: boom',
        error: ApiException('boom', statusCode: 500),
      );
      final result = await resolve(tester, state, withL10n: true);
      expect(
        result,
        'Something went wrong on our side. Please try again in a moment.',
      );
      expect(result.contains('ApiException'), isFalse);
    });

    testWidgets('collapses a raw technical errorMessage to the generic text', (
      tester,
    ) async {
      const state = RideState(
        status: RideStateStatus.error,
        errorMessage: 'Boom: server exploded',
      );
      final result = await resolve(tester, state, withL10n: true);
      expect(result, 'Something went wrong. Please try again.');
    });

    // Regression guard for the "Null check operator used on a null value"
    // crash: a null errorMessage must yield the localized fallback, never throw.
    testWidgets('returns the localized fallback when the message is null', (
      tester,
    ) async {
      const state = RideState(status: RideStateStatus.error);
      final result = await resolve(tester, state, withL10n: true);
      expect(result, 'Failed to load rides');
    });

    testWidgets(
      'returns the literal fallback when message is null and no l10n is present',
      (tester) async {
        const state = RideState(status: RideStateStatus.error);
        final result = await resolve(tester, state, withL10n: false);
        expect(result, 'Failed to load rides');
      },
    );
  });
}

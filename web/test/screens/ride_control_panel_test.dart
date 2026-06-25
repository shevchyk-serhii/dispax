import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/widgets/ride_control_panel.dart';
import 'package:dispax/theme/app_theme.dart';

import '../helpers/test_fixtures.dart';

void main() {
  // Resolves the color the framework will actually paint for the [Text] whose
  // data starts with [prefix] — accounts for the widget's own style.
  Color textColor(WidgetTester tester, String prefix) {
    final widget = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith(prefix) ?? false),
      ),
    );
    return widget.style!.color!;
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    required ThemeData theme,
    required Ride ride,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: RideControlPanel(
            ride: ride,
            onStartRide: onStart ?? () {},
            onCompleteRide: onComplete ?? () {},
          ),
        ),
      ),
    );
  }

  group('RideControlPanel text legibility', () {
    testWidgets('dark theme: client name uses onSurface, not graphite', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        clientName: 'Hans Weber',
      );
      await pumpPanel(tester, theme: AppTheme.darkTheme, ride: ride);

      // Regression: the bug rendered AppStyles.titleMedium's hardcoded
      // textPrimary (graphite) on the graphite surfaceDark → invisible.
      expect(textColor(tester, 'Hans Weber'), AppColors.textPrimaryDark);
      expect(textColor(tester, 'Hans Weber'), isNot(AppColors.textPrimary));
    });

    testWidgets('dark theme: addresses use onSurface', (tester) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        from: TestFixtures.location(address: 'Marienplatz'),
        to: TestFixtures.location(address: 'Airport'),
      );
      await pumpPanel(tester, theme: AppTheme.darkTheme, ride: ride);

      expect(textColor(tester, 'Marienplatz'), AppColors.textPrimaryDark);
    });

    testWidgets('light theme: client name stays graphite (no regression)', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        clientName: 'Hans Weber',
      );
      await pumpPanel(tester, theme: AppTheme.theme, ride: ride);

      expect(textColor(tester, 'Hans Weber'), AppColors.textPrimary);
    });
  });

  group('RideControlPanel status chip', () {
    // The chip background carries the status palette; find it by its background
    // color rather than position so the assertion is unambiguous.
    Container chipContainer(WidgetTester tester, Color background) {
      return tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == background,
        ),
      );
    }

    testWidgets('dark theme: assigned chip is not white-on-white', (
      tester,
    ) async {
      final ride = TestFixtures.ride(status: RideStatus.assigned);
      await pumpPanel(tester, theme: AppTheme.darkTheme, ride: ride);

      // Regression: the old chip used colorScheme.primary (near-white) as the
      // background with white text → unreadable. The reused badge must use the
      // dark status tint with the dark status text.
      final chip = chipContainer(tester, AppColors.rideAssignedBgDark);
      expect(
        (chip.decoration as BoxDecoration).color,
        AppColors.rideAssignedBgDark,
      );
      expect(textColor(tester, 'Assigned'), AppColors.rideAssignedTextDark);
    });

    testWidgets('light theme: assigned chip uses light tint', (tester) async {
      final ride = TestFixtures.ride(status: RideStatus.assigned);
      await pumpPanel(tester, theme: AppTheme.theme, ride: ride);

      final chip = chipContainer(tester, AppColors.rideAssignedBg);
      expect(
        (chip.decoration as BoxDecoration).color,
        AppColors.rideAssignedBg,
      );
      expect(textColor(tester, 'Assigned'), AppColors.rideAssignedText);
    });
  });

  group('RideControlPanel price', () {
    testWidgets('shows the fare with a euro symbol when priced', (
      tester,
    ) async {
      final ride = TestFixtures.ride(status: RideStatus.assigned, price: 45.5);
      await pumpPanel(tester, theme: AppTheme.theme, ride: ride);

      expect(find.text('€45.5'), findsOneWidget);
    });

    testWidgets('whole-euro fare drops the trailing decimal', (tester) async {
      final ride = TestFixtures.ride(status: RideStatus.assigned, price: 60);
      await pumpPanel(tester, theme: AppTheme.theme, ride: ride);

      expect(find.text('€60'), findsOneWidget);
    });

    testWidgets('shows no fare row when the ride has no price', (tester) async {
      final ride = TestFixtures.ride(status: RideStatus.assigned);
      await pumpPanel(tester, theme: AppTheme.theme, ride: ride);

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('€') ?? false),
        ),
        findsNothing,
      );
    });
  });

  group('RideControlPanel actions', () {
    testWidgets('assigned ride shows Start Ride and fires callback', (
      tester,
    ) async {
      var started = false;
      final ride = TestFixtures.ride(status: RideStatus.assigned);
      await pumpPanel(
        tester,
        theme: AppTheme.darkTheme,
        ride: ride,
        onStart: () => started = true,
      );

      expect(find.text('Start Ride'), findsOneWidget);
      expect(find.text('Complete Ride'), findsNothing);
      await tester.tap(find.text('Start Ride'));
      expect(started, isTrue);
    });

    testWidgets('in-progress ride shows Complete Ride and fires callback', (
      tester,
    ) async {
      var completed = false;
      final ride = TestFixtures.ride(status: RideStatus.inProgress);
      await pumpPanel(
        tester,
        theme: AppTheme.darkTheme,
        ride: ride,
        onComplete: () => completed = true,
      );

      expect(find.text('Complete Ride'), findsOneWidget);
      expect(find.text('Start Ride'), findsNothing);
      await tester.tap(find.text('Complete Ride'));
      expect(completed, isTrue);
    });
  });
}

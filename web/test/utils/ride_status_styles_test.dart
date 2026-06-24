import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/utils/ride_status_styles.dart';

void main() {
  group('RideStatusStyles brightness-aware colors', () {
    // (status, lightBg, darkBg, lightText, darkText) tuples so every status is
    // checked against both palettes from the single source of truth.
    final cases = <(RideStatus, Color, Color, Color, Color)>[
      (
        RideStatus.requested,
        AppColors.rideRequestedBg,
        AppColors.rideRequestedBgDark,
        AppColors.rideRequestedText,
        AppColors.rideRequestedTextDark,
      ),
      (
        RideStatus.assigned,
        AppColors.rideAssignedBg,
        AppColors.rideAssignedBgDark,
        AppColors.rideAssignedText,
        AppColors.rideAssignedTextDark,
      ),
      (
        RideStatus.inProgress,
        AppColors.rideInProgressBg,
        AppColors.rideInProgressBgDark,
        AppColors.rideInProgressText,
        AppColors.rideInProgressTextDark,
      ),
      (
        RideStatus.completed,
        AppColors.rideCompletedBg,
        AppColors.rideCompletedBgDark,
        AppColors.rideCompletedText,
        AppColors.rideCompletedTextDark,
      ),
      (
        RideStatus.cancelled,
        AppColors.rideCancelledBg,
        AppColors.rideCancelledBgDark,
        AppColors.rideCancelledText,
        AppColors.rideCancelledTextDark,
      ),
      // Regression: handedOff was added after initial status set; every switch
      // in RideStatusStyles must handle it (missing case → compile-time error in
      // Dart since the switch covers a sealed enum).
      (
        RideStatus.handedOff,
        AppColors.rideHandedOffBg,
        AppColors.rideHandedOffBgDark,
        AppColors.rideHandedOffText,
        AppColors.rideHandedOffTextDark,
      ),
    ];

    // ── confirmed status specific checks ────────────────────────────────────
    // Confirmed uses the success (green) palette, not the assigned palette.
    test('confirmed: background is successBg in light mode', () {
      expect(
        RideStatusStyles.getStatusBackgroundColor(RideStatus.confirmed),
        AppColors.successBg,
      );
    });

    test('confirmed: border is successBorder in light mode', () {
      expect(
        RideStatusStyles.getStatusBorderColor(RideStatus.confirmed),
        AppColors.successBorder,
      );
    });

    test('confirmed: text color is successStrong in light mode', () {
      expect(
        RideStatusStyles.getStatusTextColor(RideStatus.confirmed),
        AppColors.successStrong,
      );
    });

    test('confirmed: icon is check_circle', () {
      expect(
        RideStatusStyles.getStatusIcon(RideStatus.confirmed),
        Icons.check_circle,
      );
    });

    test('confirmed: display name is "Confirmed"', () {
      expect(
        RideStatusStyles.getStatusDisplayName(RideStatus.confirmed),
        'Confirmed',
      );
    });

    // MUTATION TARGET: if the confirmed case reused the assigned palette this would fail.
    test(
      'confirmed background differs from assigned background (green != orange)',
      () {
        final confirmedBg = RideStatusStyles.getStatusBackgroundColor(
          RideStatus.confirmed,
        );
        final assignedBg = RideStatusStyles.getStatusBackgroundColor(
          RideStatus.assigned,
        );
        expect(confirmedBg, isNot(equals(assignedBg)));
      },
    );

    for (final c in cases) {
      final (status, lightBg, darkBg, lightText, darkText) = c;

      test('${status.value}: background follows brightness', () {
        expect(
          RideStatusStyles.getStatusBackgroundColor(status),
          lightBg,
          reason: 'defaults to the light tint',
        );
        expect(
          RideStatusStyles.getStatusBackgroundColor(
            status,
            brightness: Brightness.light,
          ),
          lightBg,
        );
        expect(
          RideStatusStyles.getStatusBackgroundColor(
            status,
            brightness: Brightness.dark,
          ),
          darkBg,
        );
      });

      test('${status.value}: text follows brightness', () {
        expect(RideStatusStyles.getStatusTextColor(status), lightText);
        expect(
          RideStatusStyles.getStatusTextColor(
            status,
            brightness: Brightness.dark,
          ),
          darkText,
        );
      });

      test('${status.value}: dark text differs from light text', () {
        expect(darkText, isNot(equals(lightText)));
      });
    }

    test('border uses the named tokens in light mode', () {
      expect(
        RideStatusStyles.getStatusBorderColor(RideStatus.completed),
        AppColors.rideCompletedBorder,
      );
    });

    test('border in dark mode derives from the dark text color', () {
      expect(
        RideStatusStyles.getStatusBorderColor(
          RideStatus.completed,
          brightness: Brightness.dark,
        ),
        AppColors.rideCompletedTextDark.withValues(alpha: 0.4),
      );
    });

    // Regression: getStatusDisplayName must not throw on handedOff
    // (mutation: remove handedOff case from getStatusDisplayName switch → this fails).
    test('getStatusDisplayName returns "Handed Off" for handedOff', () {
      expect(
        RideStatusStyles.getStatusDisplayName(RideStatus.handedOff),
        'Handed Off',
      );
    });

    test('getStatusColor is brightness-independent', () {
      // The saturated status color is shared by both themes; it has no
      // brightness parameter and must stay stable.
      expect(
        RideStatusStyles.getStatusColor(RideStatus.completed),
        AppColors.rideCompleted,
      );
    });

    test('getStatusColorValue matches getStatusColor as ARGB int', () {
      // The map driver marker colours its dot from this int; it must stay the
      // single source of truth (same value as the Flutter Color).
      for (final status in RideStatus.values) {
        expect(
          RideStatusStyles.getStatusColorValue(status),
          RideStatusStyles.getStatusColor(status).toARGB32(),
          reason: '${status.value} marker colour must match the status palette',
        );
      }
    });
  });

  group('createStatusBadge', () {
    testWidgets('renders light palette under a light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => RideStatusStyles.createStatusBadge(
                RideStatus.completed,
                context: context,
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.rideCompletedBg);
    });

    testWidgets('renders dark palette under a dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => RideStatusStyles.createStatusBadge(
                RideStatus.completed,
                context: context,
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.rideCompletedBgDark);
    });

    testWidgets('falls back to light palette without a context', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: RideStatusStyles.createStatusBadge(RideStatus.completed),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.rideCompletedBg);
    });
  });
}

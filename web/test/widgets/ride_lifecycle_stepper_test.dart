import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/ride_lifecycle_stepper.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/constants/lucide_compat.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Ride _ride(RideStatus status) => Ride(
  id: 'test-id',
  clientId: 'client',
  creatorId: 'creator',
  companyId: 'company',
  pickupDateTime: DateTime(2025, 1, 1, 9, 0),
  from: const Location(address: 'A'),
  to: const Location(address: 'B'),
  status: status,
  clientName: 'Test Client',
);

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

/// Count how many [Icon] widgets in the tree use the given [IconData].
int _countIcons(WidgetTester tester, IconData data) {
  return tester
      .widgetList<Icon>(find.byType(Icon))
      .where((i) => i.icon == data)
      .length;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RideLifecycleStepperWidget — basic rendering', () {
    testWidgets('renders "Ride Status" title', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Ride Status'), findsOneWidget);
    });

    testWidgets('AnimationController disposes without error', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.assigned))),
      );
      await tester.pump(Duration.zero);
      // Unmount to trigger dispose() — must not throw.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RideLifecycleStepperWidget(ride: _ride(RideStatus.inProgress)),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(Duration.zero);
      expect(find.byType(RideLifecycleStepperWidget), findsOneWidget);
    });
  });

  group('RideLifecycleStepperWidget — step labels per status', () {
    testWidgets('requested: shows "Requested" label', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Requested'), findsOneWidget);
    });

    testWidgets('assigned: shows "Assigned" label', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.assigned))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Assigned'), findsOneWidget);
    });

    testWidgets('inProgress: shows "In Progress" label', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.inProgress))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('completed: shows all 4 step labels', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.completed))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('cancelled: shows "Cancelled" text', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.cancelled))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Cancelled'), findsOneWidget);
    });
  });

  group('RideLifecycleStepperWidget — check icons per status', () {
    // For `requested` (index 0): no step is completed yet → 0 checkmarks.
    testWidgets('requested: no checkmark icons (no completed step)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
      );
      await tester.pump(Duration.zero);
      expect(
        _countIcons(tester, LucideCompat.check),
        equals(0),
        reason: 'requested is step 0; nothing before it is completed',
      );
    });

    // For `assigned` (index 1): step 0 (Requested) is completed → 1 checkmark.
    testWidgets('assigned: exactly 1 checkmark (Requested step completed)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.assigned))),
      );
      await tester.pump(Duration.zero);
      expect(
        _countIcons(tester, LucideCompat.check),
        equals(1),
        reason: 'Requested (step 0) is completed; Assigned is current',
      );
    });

    // For `inProgress` (index 2): steps 0 and 1 completed → 2 checkmarks.
    testWidgets(
      'inProgress: exactly 2 checkmarks (Requested + Assigned done)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.inProgress))),
        );
        await tester.pump(Duration.zero);
        expect(
          _countIcons(tester, LucideCompat.check),
          equals(2),
          reason: 'Requested and Assigned are completed; InProgress is current',
        );
      },
    );

    // For `completed` (index 3): steps 0, 1, 2 have isCompleted=true
    // (i < _currentStepIndex=3) → 3 checkmarks.
    // Step 3 (Completed itself) is isCurrent=true → pulsing dot, no checkmark.
    testWidgets(
      'completed: exactly 3 checkmarks (steps 0-2 done; step 3 is current)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.completed))),
        );
        await tester.pump(Duration.zero);
        expect(
          _countIcons(tester, LucideCompat.check),
          equals(3),
          reason:
              'steps 0,1,2 (Requested,Assigned,InProgress) are completed; '
              'step 3 (Completed) is the current step and shows a pulsing dot',
        );
      },
    );

    // For `cancelled`: the cancelled indicator uses LucideCompat.x, not check.
    testWidgets('cancelled: shows X icon (not check), no checkmarks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.cancelled))),
      );
      await tester.pump(Duration.zero);
      expect(
        _countIcons(tester, LucideCompat.check),
        equals(0),
        reason: 'cancelled uses the X indicator, not the step check icons',
      );
      expect(
        _countIcons(tester, LucideCompat.x),
        greaterThanOrEqualTo(1),
        reason: 'cancelled indicator uses LucideCompat.x',
      );
    });
  });

  group('RideLifecycleStepperWidget — cancelled colour', () {
    testWidgets('cancelled indicator dot uses rideCancelled colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.cancelled))),
      );
      await tester.pump(Duration.zero);

      // The cancelled dot is a 20×20 circle Container with AppColors.rideCancelled.
      final dots = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final deco = c.decoration;
        if (deco is BoxDecoration) {
          return deco.shape == BoxShape.circle &&
              deco.color == AppColors.rideCancelled;
        }
        return false;
      }).toList();

      expect(
        dots.isNotEmpty,
        isTrue,
        reason:
            'cancelled indicator should have a circle Container with rideCancelled colour',
      );
    });
  });

  group('RideLifecycleStepperWidget — pulsing dot (current step)', () {
    // The stepper's AnimatedBuilder for the pulsing dot is ONE extra on top
    // of the framework ABs (Scaffold, ScrollView, etc.).  We measure the
    // count: non-cancelled statuses add +1; cancelled adds +0.
    //
    // Baseline (same scaffold wrapper, empty body) = 2 framework ABs.
    // Non-cancelled statuses → 3 total ABs (2 framework + 1 stepper pulse).
    // Cancelled → 2 total ABs (2 framework, 0 stepper pulse).

    Widget baseline() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('en'),
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: const Padding(padding: EdgeInsets.all(16), child: SizedBox()),
        ),
      ),
    );

    int abCount(WidgetTester t) =>
        t.widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder)).length;

    testWidgets(
      'requested: one extra AnimatedBuilder vs baseline (pulsing dot present)',
      (tester) async {
        await tester.pumpWidget(baseline());
        final baselineCount = abCount(tester);

        await tester.pumpWidget(
          _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
        );
        await tester.pump(Duration.zero);

        expect(
          abCount(tester),
          equals(baselineCount + 1),
          reason:
              'requested is the current step — one pulsing AnimatedBuilder added',
        );
      },
    );

    testWidgets(
      'completed: one extra AnimatedBuilder (Completed step is current/pulsing)',
      (tester) async {
        await tester.pumpWidget(baseline());
        final baselineCount = abCount(tester);

        await tester.pumpWidget(
          _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.completed))),
        );
        await tester.pump(Duration.zero);

        expect(
          abCount(tester),
          equals(baselineCount + 1),
          reason:
              'completed is the current step (index 3); it shows a pulsing dot '
              '— one extra AnimatedBuilder present',
        );
      },
    );

    testWidgets(
      'cancelled: NO extra AnimatedBuilder vs baseline (no pulsing dot)',
      (tester) async {
        await tester.pumpWidget(baseline());
        final baselineCount = abCount(tester);

        await tester.pumpWidget(
          _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.cancelled))),
        );
        await tester.pump(Duration.zero);

        expect(
          abCount(tester),
          equals(baselineCount),
          reason:
              'cancelled uses the special indicator widget (no AnimatedBuilder step dot)',
        );
      },
    );
  });

  group('RideLifecycleStepperWidget — isClientView sub-labels', () {
    testWidgets(
      'isClientView: shows "Waiting for driver assignment" for requested',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            RideLifecycleStepperWidget(
              ride: _ride(RideStatus.requested),
              isClientView: true,
            ),
          ),
        );
        await tester.pump(Duration.zero);
        expect(find.text('Waiting for driver assignment'), findsOneWidget);
      },
    );

    testWidgets(
      'default (driver) view: shows "Awaiting assignment" for requested',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            RideLifecycleStepperWidget(
              ride: _ride(RideStatus.requested),
              isClientView: false,
            ),
          ),
        );
        await tester.pump(Duration.zero);
        expect(find.text('Awaiting assignment'), findsOneWidget);
      },
    );
  });
}

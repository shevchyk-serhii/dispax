import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/ride_lifecycle_stepper.dart';
import 'package:dispax/modules/core/models/location.dart';

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
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  group('RideLifecycleStepperWidget', () {
    testWidgets('renders "Ride Status" title', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Ride Status'), findsOneWidget);
    });

    testWidgets('shows status label for requested', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.requested))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Requested'), findsOneWidget);
    });

    testWidgets('shows status label for inProgress', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.inProgress))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('shows all 4 step labels when completed', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.completed))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('shows Cancelled text for cancelled status', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.cancelled))),
      );
      await tester.pump(Duration.zero);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('AnimationController disposes without error', (tester) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.assigned))),
      );
      await tester.pump(Duration.zero);
      // Unmount the widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // No error should be thrown
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

    testWidgets('shows step dots (Containers) for each status step', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RideLifecycleStepperWidget(ride: _ride(RideStatus.assigned))),
      );
      await tester.pump(Duration.zero);
      // There should be multiple Container widgets for the dots
      expect(find.byType(Container), findsWidgets);
    });
  });
}
